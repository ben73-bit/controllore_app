import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'lib/models/lesson.dart';
import 'lib/models/contract.dart';

Future<void> main() async {
  print('Inizializzazione Supabase...');
  await Supabase.initialize(
    url: 'https://vwytuyexzbxkrncllyec.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3eXR1eWV4emJ4a3JuY2xseWVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMjkxMzksImV4cCI6MjA5NzgwNTEzOX0.YweByFnt2Xbh6CDWJ6I87aMQM3719sLxd9Z2TaUfbcg',
  );

  final client = Supabase.instance.client;
  
  print('Recupero contratti...');
  final contractsRes = await client.from('contracts').select().limit(1);
  if (contractsRes.isEmpty) {
    print('Nessun contratto trovato.');
    return;
  }
  
  final contract = Contract.fromJson(contractsRes.first);
  print('Uso contratto: ${contract.id}');

  final lesson = Lesson(
    id: const Uuid().v4(),
    contractId: contract.id,
    startDateTime: DateTime.now(),
    duration: '01:00:00',
    isConfirmed: true,
    summary: 'Test da terminale',
    amount: 50.0,
    isBilled: false,
  );

  print('Provo a inserire lezione...');
  try {
    final res = await client.from('lessons').insert(lesson.toJson()).select().single();
    print('INSERIMENTO RIUSCITO: $res');
  } catch (e) {
    print('ERRORE DURANTE INSERIMENTO:');
    print(e.toString());
  }
}
