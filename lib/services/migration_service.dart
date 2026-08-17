import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MigrationResult {
  final int contractsCount;
  final int lessonsCount;
  final String fileName;

  MigrationResult({
    required this.contractsCount,
    required this.lessonsCount,
    required this.fileName,
  });
}

class MigrationService {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  /// Apre il file picker per selezionare il file JSON di esportazione desktop.
  Future<PlatformFile?> pickJsonFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.first;
  }

  /// Apre il file picker ed esegue l'importazione.
  Future<MigrationResult?> pickAndImportDesktopJson() async {
    final platformFile = await pickJsonFile();
    if (platformFile == null) return null;

    String jsonString;
    if (platformFile.bytes != null) {
      jsonString = utf8.decode(platformFile.bytes!);
    } else if (platformFile.path != null) {
      final file = File(platformFile.path!);
      jsonString = await file.readAsString();
    } else {
      throw Exception('Impossibile leggere i dati dal file selezionato.');
    }

    return await importFromJsonString(
      jsonString: jsonString,
      fileName: platformFile.name,
    );
  }

  /// Esegue la migrazione a partire da una stringa JSON decodificata.
  Future<MigrationResult> importFromJsonString({
    required String jsonString,
    String fileName = 'UserData.json',
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Nessun utente autenticato. Effettua prima l\'accesso.');
    }
    final userId = currentUser.id;

    // 1. Decodifica JSON
    final dynamic decoded = jsonDecode(jsonString);
    List<dynamic> contractsList = [];

    if (decoded is List) {
      contractsList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['Contracts'] is List) {
        contractsList = decoded['Contracts'] as List;
      } else if (decoded['contracts'] is List) {
        contractsList = decoded['contracts'] as List;
      } else {
        throw Exception(
          'Formato JSON non riconosciuto: la chiave "Contracts" non è presente.',
        );
      }
    } else {
      throw Exception('Il file selezionato non contiene un JSON valido.');
    }

    // 2. Mappa per deduplicare e raggruppare i contratti
    // Chiave univoca: "$companyName|$contractNumber"
    final Map<String, String> existingContractIds = {};
    int importedContracts = 0;

    // Mappa per deduplicare tutte le lezioni prima dell'inserimento batch
    // Chiave univoca: Uid della lezione
    final Map<String, Map<String, dynamic>> uniqueLessons = {};

    for (final rawContract in contractsList) {
      if (rawContract is! Map) continue;
      final contractMap = Map<String, dynamic>.from(rawContract);

      final companyName = (contractMap['Company'] ??
              contractMap['company_name'] ??
              'Azienda Senza Nome')
          .toString()
          .trim();
      final contractNumber = (contractMap['ContractNumber'] ??
              contractMap['contract_number'])
          ?.toString()
          .trim();

      final contractDeduplicationKey = '$companyName|${contractNumber ?? ''}';

      String contractId;

      if (existingContractIds.containsKey(contractDeduplicationKey)) {
        // Contratto già creato/trovato in questo ciclo
        contractId = existingContractIds[contractDeduplicationKey]!;
      } else {
        // Verifica se il contratto esiste già su Supabase per questo utente
        var query = _client
            .from('contracts')
            .select('id')
            .eq('user_id', userId)
            .eq('company_name', companyName);

        final List<dynamic> existingDbContracts =
            contractNumber != null && contractNumber.isNotEmpty
                ? await query.eq('contract_number', contractNumber)
                : await query.isFilter('contract_number', null);

        if (existingDbContracts.isNotEmpty) {
          contractId = existingDbContracts.first['id'] as String;
        } else {
          // Creazione nuovo contratto
          final hourlyRate = double.tryParse(
                (contractMap['HourlyRate'] ?? contractMap['hourly_rate'] ?? '0')
                    .toString(),
              ) ??
              0.0;
          final totalHoursLimit = double.tryParse(
            (contractMap['TotalHours'] ?? contractMap['total_hours_limit'] ?? '')
                .toString(),
          );
          final billedHours = double.tryParse(
            (contractMap['BilledHours'] ?? contractMap['billed_hours'] ?? '')
                .toString(),
          );

          DateTime startDate;
          final rawStartDate =
              contractMap['StartDate'] ?? contractMap['start_date'];
          if (rawStartDate != null) {
            startDate = DateTime.tryParse(rawStartDate.toString()) ?? DateTime.now();
          } else {
            startDate = DateTime.now();
          }

          DateTime? endDate;
          final rawEndDate = contractMap['EndDate'] ?? contractMap['end_date'];
          if (rawEndDate != null) {
            endDate = DateTime.tryParse(rawEndDate.toString());
          }

          final contractPayload = <String, dynamic>{
            'company_name': companyName,
            if (contractNumber != null && contractNumber.isNotEmpty)
              'contract_number': contractNumber,
            'hourly_rate': hourlyRate,
            'total_hours_limit': ?totalHoursLimit,
            'billed_hours': ?billedHours,
            'start_date': startDate.toUtc().toIso8601String(),
            if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
            'user_id': userId,
          };

          final contractRes = await _client
              .from('contracts')
              .insert(contractPayload)
              .select('id')
              .single();

          contractId = contractRes['id'] as String;
          importedContracts++;
        }

        existingContractIds[contractDeduplicationKey] = contractId;
      }

      // 3. Elaborazione e deduplicazione delle lezioni annidate
      final rawLessons = contractMap['Lessons'] ?? contractMap['lessons'];
      if (rawLessons is List && rawLessons.isNotEmpty) {
        for (final rawLesson in rawLessons) {
          if (rawLesson is! Map) continue;
          final lessonMap = Map<String, dynamic>.from(rawLesson);

          // Calcola/valida Uid univoco
          final rawUid = lessonMap['Uid'] ?? lessonMap['uid'] ?? lessonMap['id'];
          final uid = (rawUid != null && rawUid.toString().trim().isNotEmpty)
              ? rawUid.toString().trim()
              : _uuid.v4();

          final rawLessonStart =
              lessonMap['StartDateTime'] ?? lessonMap['start_date_time'];
          DateTime lessonStart;
          if (rawLessonStart != null) {
            lessonStart =
                DateTime.tryParse(rawLessonStart.toString()) ?? DateTime.now();
          } else {
            lessonStart = DateTime.now();
          }

          final duration =
              (lessonMap['Duration'] ?? lessonMap['duration'] ?? '00:00:00')
                  .toString();
          final isConfirmed = lessonMap['IsConfirmed'] == true ||
              lessonMap['is_confirmed'] == true;
          final summary =
              lessonMap['Summary']?.toString() ?? lessonMap['summary']?.toString();
          final description = lessonMap['Description']?.toString() ??
              lessonMap['description']?.toString();
          final location =
              lessonMap['Location']?.toString() ?? lessonMap['location']?.toString();
          final isBilled =
              lessonMap['IsBilled'] == true || lessonMap['is_billed'] == true;
          final invoiceNumber = lessonMap['InvoiceNumber']?.toString() ??
              lessonMap['invoice_number']?.toString();

          DateTime? invoiceDate;
          final rawInvoiceDate =
              lessonMap['InvoiceDate'] ?? lessonMap['invoice_date'];
          if (rawInvoiceDate != null) {
            invoiceDate = DateTime.tryParse(rawInvoiceDate.toString());
          }

          final amount = double.tryParse(
            (lessonMap['Amount'] ?? lessonMap['amount'] ?? '').toString(),
          );
          final isPaid =
              lessonMap['IsPaid'] == true || lessonMap['is_paid'] == true;

          final lessonData = <String, dynamic>{
            'id': uid,
            'contract_id': contractId,
            'user_id': userId,
            'start_date_time': lessonStart.toUtc().toIso8601String(),
            'duration': duration,
            'is_confirmed': isConfirmed,
            'summary': summary,
            'description': description,
            'location': location,
            'is_billed': isBilled,
            'invoice_number': invoiceNumber,
            if (invoiceDate != null)
              'invoice_date': invoiceDate.toUtc().toIso8601String(),
            'amount': ?amount,
            'is_paid': isPaid,
          };

          // Se l'UID è già stato inserito, sovrascrivi o preferisci quella confermata
          if (!uniqueLessons.containsKey(uid) || isConfirmed) {
            uniqueLessons[uid] = lessonData;
          }
        }
      }
    }

    // 4. Inserimento massivo a blocchi (batching) con onConflict: 'id'
    // Garantisce che nessun batch contenga duplicati dello stesso id
    final allLessons = uniqueLessons.values.toList();
    const batchSize = 100;

    for (int i = 0; i < allLessons.length; i += batchSize) {
      final end = (i + batchSize < allLessons.length)
          ? i + batchSize
          : allLessons.length;
      final batch = allLessons.sublist(i, end);

      await _client.from('lessons').upsert(
            batch,
            onConflict: 'id',
          );
    }

    if (kDebugMode) {
      print(
        'Migrazione completata: $importedContracts contratti nuovi, ${allLessons.length} lezioni univoche.',
      );
    }

    return MigrationResult(
      contractsCount: existingContractIds.length,
      lessonsCount: allLessons.length,
      fileName: fileName,
    );
  }
}
