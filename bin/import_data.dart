import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:controllore_app/models/contract.dart';
import 'package:controllore_app/models/lesson.dart';

// Sostituisci con le tue chiavi se necessario (devono essere uguali a quelle in main.dart)
const String supabaseUrl = 'https://vwytuyexzbxkrncllyec.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3eXR1eWV4emJ4a3JuY2xseWVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMjkxMzksImV4cCI6MjA5NzgwNTEzOX0.YweByFnt2Xbh6CDWJ6I87aMQM3719sLxd9Z2TaUfbcg';

void main() async {
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('Leggendo UserData.json...');
  final file = File('UserData.json');
  if (!await file.exists()) {
    print('Errore: UserData.json non trovato!');
    return;
  }

  final String jsonString = await file.readAsString();
  final Map<String, dynamic> jsonData = jsonDecode(jsonString);

  final List<dynamic> rawContracts = jsonData['Contracts'] ?? [];

  print('Trovati ${rawContracts.length} contratti da importare.');

  for (var rawContract in rawContracts) {
    try {
      // 1. Parsing del contratto dal JSON originale
      final contract = Contract.fromJson(rawContract);

      print('Inserimento contratto: ${contract.companyName}...');

      // 2. Inserimento del contratto in Supabase (recuperiamo l'ID generato dal DB)
      final List<dynamic> contractResponse = await supabase
          .from('contracts')
          .insert(contract.toJson())
          .select();

      if (contractResponse.isNotEmpty) {
        final insertedContractId = contractResponse.first['id'] as String;
        print('Contratto inserito con ID: $insertedContractId');

        // 3. Recupero e parsing delle lezioni di questo contratto
        final List<dynamic> rawLessons = rawContract['Lessons'] ?? [];
        if (rawLessons.isNotEmpty) {
          print(
            'Importazione di ${rawLessons.length} lezioni per questo contratto...',
          );

          List<Map<String, dynamic>> lessonsToInsert = [];

          // Filtriamo le lezioni duplicandole per ID in memoria prima di inviarle,
          // per evitare l'errore PostgreSQL "ON CONFLICT DO UPDATE command cannot affect row a second time"
          Map<String, Map<String, dynamic>> uniqueLessons = {};

          for (var rawLesson in rawLessons) {
            final lesson = Lesson.fromJson(rawLesson);

            // Impostiamo il contract_id generato da Supabase per mantenere la relazione
            final lessonJson = lesson.toJson();
            lessonJson['contract_id'] = insertedContractId;
            uniqueLessons[lesson.id] = lessonJson;
          }

          lessonsToInsert = uniqueLessons.values.toList();

          // 4. Inserimento massivo (batch) delle lezioni con UPSERT per ignorare i duplicati
          await supabase
              .from('lessons')
              .upsert(lessonsToInsert, onConflict: 'id');
          print('Lezioni inserite con successo.');
        }
      }
    } catch (e) {
      print('Errore durante l\'inserimento di un contratto: $e');
    }
  }

  print('Importazione completata!');
  exit(0);
}
