import '../models/lesson.dart';

class IcsParser {
  /// Analizza il contenuto di un file .ics e restituisce una lista di Lesson.
  /// Gestisce i formati base di DTSTART e DTEND.
  static List<Lesson> parse(String icsContent) {
    final List<Lesson> lessons = [];
    final lines = icsContent.split(RegExp(r'\r\n|\n|\r'));

    bool inEvent = false;
    DateTime? start;
    DateTime? end;
    String? summary;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Gestione del fold delle righe nel formato ICS (le righe continuano se iniziano con spazio)
      while (i + 1 < lines.length && (lines[i + 1].startsWith(' ') || lines[i + 1].startsWith('\t'))) {
        line += lines[i + 1].substring(1);
        i++;
      }

      if (line.startsWith('BEGIN:VEVENT')) {
        inEvent = true;
        start = null;
        end = null;
        summary = null;
      } else if (line.startsWith('END:VEVENT')) {
        if (inEvent && start != null && end != null) {
          // Calcola durata HH:mm
          final durationMinutes = end.difference(start).inMinutes;
          final h = durationMinutes ~/ 60;
          final m = durationMinutes % 60;
          final durationStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

          lessons.add(Lesson(
            id: '', // Sarà generato dal database o prima dell'inserimento
            contractId: '', // Da assegnare in fase di importazione
            startDateTime: start,
            duration: durationStr,
            summary: summary,
          ));
        }
        inEvent = false;
      } else if (inEvent) {
        if (line.startsWith('DTSTART')) {
          start = _parseDate(line);
        } else if (line.startsWith('DTEND')) {
          end = _parseDate(line);
        } else if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8).trim();
          // Decodifica backslash
          summary = summary.replaceAll(r'\,', ',').replaceAll(r'\;', ';').replaceAll(r'\n', '\n');
        }
      }
    }

    // Ordina per data
    lessons.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return lessons;
  }

  static DateTime? _parseDate(String line) {
    // DTSTART:20260601T100000Z
    // DTSTART;TZID=Europe/Rome:20260601T100000
    // DTSTART;VALUE=DATE:20260601
    
    final colonIdx = line.indexOf(':');
    if (colonIdx == -1) return null;

    final dateStr = line.substring(colonIdx + 1).trim();
    if (dateStr.isEmpty) return null;

    try {
      if (dateStr.length == 8) {
        // Formato solo data YYYYMMDD
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      } else if (dateStr.length >= 15) {
        // Formato YYYYMMDDTHHMMSS
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        
        final isUtc = dateStr.endsWith('Z');
        if (isUtc) {
          return DateTime.utc(year, month, day, hour, minute, second).toLocal();
        } else {
          // ICS senza 'Z' ma magari con TZID.
          // In questa app semplice consideriamo l'orario già locale.
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    } catch (e) {
      // Ignora errori di parsing
    }
    return null;
  }
}
