import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contract.dart';
import '../models/lesson.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Contratti ---
  
  Future<List<Contract>> getContracts() async {
    final response = await _client.from('contracts').select().order('start_date', ascending: false);
    return (response as List).map((json) => Contract.fromJson(json)).toList();
  }

  Future<Contract> insertContract(Contract contract) async {
    final response = await _client.from('contracts').insert(contract.toJson()).select().single();
    return Contract.fromJson(response);
  }

  // --- Lezioni ---

  Future<List<Lesson>> getRecentLessons({int limit = 5}) async {
    final response = await _client.from('lessons').select().order('start_date_time', ascending: false).limit(limit);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }
  
  Future<List<Lesson>> getLessonsForContract(String contractId) async {
    final response = await _client.from('lessons').select().eq('contract_id', contractId).order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  Future<Lesson> insertLesson(Lesson lesson) async {
    final response = await _client.from('lessons').insert(lesson.toJson()).select().single();
    return Lesson.fromJson(response);
  }
  
  // --- Calcoli Statistici (Opzionale: da spostare backend side se i dati sono molti) ---
  
  Future<Map<String, dynamic>> getDashboardStats() async {
    // Nota: in un'app di produzione con molti dati, queste aggregazioni si fanno
    // tramite una View o una Stored Procedure in PostgreSQL.
    // Per ora le simuliamo raggruppando i dati.
    
    final lessons = await _client.from('lessons').select('duration, amount');
    
    double totalHours = 0.0;
    double totalAmount = 0.0;
    
    for (var l in lessons) {
      final durationStr = l['duration'] as String?;
      if (durationStr != null && durationStr.isNotEmpty) {
        final parts = durationStr.split(':');
        if (parts.length >= 2) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          totalHours += hours + (minutes / 60.0);
        }
      }
      totalAmount += (l['amount'] as num?)?.toDouble() ?? 0.0;
    }
    
    return {
      'total_hours': totalHours,
      'total_amount': totalAmount,
    };
  }
}
