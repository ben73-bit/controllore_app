import '../models/lesson.dart';

class IcsParser {
  /// Analizza il contenuto di un file .ics (iCalendar) e restituisce una lista di Lesson.
  /// Rispetta le specifiche RFC 5545:
  /// - Line unfolding: le righe che iniziano con spazio/tab sono la continuazione della precedente.
  /// - Esclusione degli eventi con STATUS:CANCELLED.
  /// - Parsing accurato di DTSTART/DTEND con supporto UTC (Z) e timezone locali.
  /// - Decodifica dei caratteri speciali escaped (\,  \;  \\  \n).
  static List<Lesson> parse(String icsContent) {
    final List<Lesson> lessons = [];

    // ── 1. Line Unfolding conforme a RFC 5545 ───────────────────────────────
    // Le righe che iniziano con ' ' o '\t' sono la continuazione della riga precedente.
    final rawLines = icsContent.split(RegExp(r'\r\n|\n|\r'));
    final List<String> unfoldedLines = [];

    for (final line in rawLines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfoldedLines.isNotEmpty) {
        unfoldedLines[unfoldedLines.length - 1] += line.substring(1);
      } else {
        unfoldedLines.add(line);
      }
    }

    // ── 2. Parsing dei VEVENT ────────────────────────────────────────────────
    bool inEvent = false;
    bool isCancelled = false;
    DateTime? start;
    DateTime? end;
    String? summary;
    String? uid;

    for (final line in unfoldedLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final upperTrimmed = trimmed.toUpperCase();

      if (upperTrimmed == 'BEGIN:VEVENT') {
        inEvent = true;
        isCancelled = false;
        start = null;
        end = null;
        summary = null;
        uid = null;
      } else if (upperTrimmed == 'END:VEVENT') {
        if (inEvent && !isCancelled && start != null && end != null) {
          // Guardia: se end ≤ start per errore nel file, impostiamo 1 ora di default.
          if (!end.isAfter(start)) {
            end = start.add(const Duration(hours: 1));
          }

          final durationMinutes = end.difference(start).inMinutes;
          final h = durationMinutes ~/ 60;
          final m = durationMinutes % 60;
          final durationStr =
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

          lessons.add(Lesson(
            id: uid ?? '',
            contractId: '',
            startDateTime: start,
            duration: durationStr,
            summary: summary,
          ));
        }
        inEvent = false;
      } else if (inEvent) {
        // STATUS
        if (upperTrimmed.startsWith('STATUS:') &&
            upperTrimmed.contains('CANCELLED')) {
          isCancelled = true;
        }
        // DTSTART (anche con parametri, es. DTSTART;TZID=...)
        else if (upperTrimmed.startsWith('DTSTART')) {
          start = _parseDate(trimmed);
        }
        // DTEND (anche con parametri, es. DTEND;TZID=...)
        else if (upperTrimmed.startsWith('DTEND')) {
          end = _parseDate(trimmed);
        }
        // SUMMARY (anche con parametri, es. SUMMARY;LANGUAGE=...)
        else if (upperTrimmed.startsWith('SUMMARY')) {
          final colonIdx = trimmed.indexOf(':');
          if (colonIdx != -1) {
            summary = _unescapeIcsText(trimmed.substring(colonIdx + 1));
          }
        }
        // UID
        else if (upperTrimmed.startsWith('UID:')) {
          uid = trimmed.substring(4).trim();
        }
      }
    }

    // ── 3. Ordinamento cronologico ───────────────────────────────────────────
    lessons.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return lessons;
  }

  // ── Parsing data/ora da una riga iCalendar ──────────────────────────────────
  // Formati supportati:
  //   DTSTART:20260601T100000Z          → UTC → converti in locale
  //   DTSTART;TZID=Europe/Rome:20260601T100000  → già locale (TZID ignorato)
  //   DTSTART;VALUE=DATE:20260601       → solo data → usa 09:00 locale
  //   DTSTART:20260601T100000           → già locale
  static DateTime? _parseDate(String line) {
    // Trova il ':' che separa il nome della proprietà dal valore.
    // Attenzione: DTSTART;TZID=Europe/Rome:20260601T100000
    // Il primo ':' potrebbe non essere quello giusto se è dentro un parametro.
    // RFC 5545: il valore inizia dopo l'ULTIMO ':' che non fa parte di un TZID.
    // Strategia semplice ma corretta: cerchiamo il primo ':' che NON sia
    // preceduto da '=' (cioè non è un valore di parametro come TZID=...).
    final colonIdx = _valueColonIndex(line);
    if (colonIdx == -1) return null;

    final dateStr = line.substring(colonIdx + 1).trim();
    if (dateStr.isEmpty) return null;

    try {
      // ── Caso 1: solo data YYYYMMDD (eventi tutto il giorno) ──────────────
      if (dateStr.length == 8 && RegExp(r'^\d{8}$').hasMatch(dateStr)) {
        return DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
          9, 0, // orario predefinito 09:00 per eventi all-day
        );
      }

      // ── Caso 2: data+ora YYYYMMDDTHHMMSS[Z] ─────────────────────────────
      if (dateStr.length >= 15 && dateStr[8] == 'T') {
        final year   = int.parse(dateStr.substring(0, 4));
        final month  = int.parse(dateStr.substring(4, 6));
        final day    = int.parse(dateStr.substring(6, 8));
        final hour   = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        final isUtc  = dateStr.toUpperCase().endsWith('Z');

        if (isUtc) {
          return DateTime.utc(year, month, day, hour, minute, second).toLocal();
        } else {
          return DateTime(year, month, day, hour, minute, second);
        }
      }

      // ── Caso 3: fallback ISO 8601 standard ───────────────────────────────
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        return dateStr.toUpperCase().endsWith('Z') ? parsed.toLocal() : parsed;
      }
    } catch (_) {
      // Ignora singoli errori di parsing
    }

    return null;
  }

  /// Trova l'indice del ':' che introduce il VALORE della proprietà iCalendar,
  /// scartando i ':' che compaiono all'interno dei parametri (es. TZID=...).
  /// In pratica: il valore parte dal primo ':' che non sia seguito da '=' a sinistra.
  static int _valueColonIndex(String line) {
    bool inParam = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == ';') {
        inParam = true; // Inizia un parametro
      } else if (ch == ':') {
        if (!inParam) return i; // Primo ':' fuori da parametri = inizio valore
        // Siamo dentro un parametro (es. TZID=Europe/Rome): questo ':' è nel valore del parametro?
        // In RFC 5545 i valori di parametro tra virgolette possono contenere ':', ma senza virgolette no.
        // Dopo il ':' di un parametro segue il valore della proprietà.
        // Esempio: DTSTART;TZID=Europe/Rome:20260601T100000
        // Il ';' ha innescato inParam, e il ':' dopo "Rome" è il separatore valore.
        inParam = false;
        return i;
      }
    }
    return -1;
  }

  /// Decodifica i caratteri d'escape nel testo iCalendar (RFC 5545 §3.3.11)
  static String _unescapeIcsText(String text) {
    return text
        .trim()
        .replaceAll(r'\\', '\x00') // segnaposto temporaneo per backslash letterale
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll('\x00', '\\'); // ripristina backslash letterale
  }
}
