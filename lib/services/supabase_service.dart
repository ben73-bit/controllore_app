import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contract.dart';
import '../models/lesson.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Contratti ---

  Future<List<Contract>> getContracts() async {
    final response = await _client
        .from('contracts')
        .select()
        .order('start_date', ascending: false);
    return (response as List).map((json) => Contract.fromJson(json)).toList();
  }

  Future<Contract> insertContract(Contract contract) async {
    final response = await _client
        .from('contracts')
        .insert(contract.toJson())
        .select()
        .single();
    return Contract.fromJson(response);
  }

  Future<void> updateContract(Contract contract) async {
    await _client
        .from('contracts')
        .update(contract.toJson())
        .eq('id', contract.id!);
  }

  Future<void> deleteContract(String contractId) async {
    await _client.from('contracts').delete().eq('id', contractId);
  }

  // --- Lezioni ---

  Future<List<Lesson>> getRecentLessons({int limit = 5}) async {
    final response = await _client
        .from('lessons')
        .select()
        .order('start_date_time', ascending: false)
        .limit(limit);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  Future<List<Lesson>> getLessonsForContract(String contractId) async {
    final response = await _client
        .from('lessons')
        .select()
        .eq('contract_id', contractId)
        .order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  Future<Lesson> insertLesson(Lesson lesson) async {
    final response = await _client
        .from('lessons')
        .insert(lesson.toJson())
        .select()
        .single();
    return Lesson.fromJson(response);
  }

  Future<void> updateLesson(Lesson lesson) async {
    await _client.from('lessons').update(lesson.toJson()).eq('id', lesson.id);
  }

  /// Inserisce una lista di lezioni in blocco.
  Future<void> insertLessons(List<Lesson> lessons) async {
    if (lessons.isEmpty) return;

    // Convertiamo le lezioni in JSON
    final items = lessons.map((l) {
      final json = l.toJson();
      // Rimuoviamo l'id se vuoto (verrà autogenerato dal DB oppure usiamo un ID locale)
      if (json['id'] == '') {
        json.remove('id');
      }
      return json;
    }).toList();

    await _client.from('lessons').insert(items);
  }

  Future<void> deleteLesson(String lessonId) async {
    await _client.from('lessons').delete().eq('id', lessonId);
  }

  /// Segna le lezioni selezionate come fatturate con un numero fattura e data.
  Future<void> markLessonsAsBilled({
    required List<String> lessonIds,
    required String invoiceNumber,
    required DateTime invoiceDate,
  }) async {
    await _client
        .from('lessons')
        .update({
          'is_billed': true,
          'invoice_number': invoiceNumber,
          'invoice_date': invoiceDate.toIso8601String(),
        })
        .inFilter('id', lessonIds);
  }

  /// Rimuove la marcatura di fatturazione da una lezione.
  Future<void> unmarkLessonBilling(String lessonId) async {
    await _client
        .from('lessons')
        .update({
          'is_billed': false,
          'invoice_number': null,
          'invoice_date': null,
        })
        .eq('id', lessonId);
  }

  /// Restituisce tutte le lezioni non ancora fatturate.
  Future<List<Lesson>> getUnbilledLessons() async {
    final response = await _client
        .from('lessons')
        .select()
        .eq('is_billed', false)
        .order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  /// Restituisce tutte le lezioni fatturate (ordinate per fattura e data).
  Future<List<Lesson>> getBilledLessons() async {
    final response = await _client
        .from('lessons')
        .select()
        .eq('is_billed', true)
        .order('invoice_date', ascending: false)
        .order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  /// Lezioni filtrabili per contratto e/o intervallo date.
  /// Usato dalla schermata Lista Lezioni.
  Future<List<Lesson>> getLessonsFiltered({
    String? contractId,
    DateTime? from,
    DateTime? to,
  }) async {
    // Costruiamo la query partendo dal FilterBuilder (prima di order/limit)
    var query = _client.from('lessons').select();

    if (contractId != null) {
      query = query.eq('contract_id', contractId);
    }
    if (from != null) {
      query = query.gte('start_date_time', from.toIso8601String());
    }
    if (to != null) {
      query = query.lt('start_date_time', to.toIso8601String());
    }

    final response = await query.order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  // --- Calcoli Statistici ---

  /// Statistiche globali (tutto lo storico)
  Future<Map<String, dynamic>> getDashboardStats() async {
    final lessons = await _client.from('lessons').select('duration, amount');
    return _aggregateLessons(lessons);
  }

  /// Statistiche filtrate per mese/anno specifico
  Future<Map<String, dynamic>> getDashboardStatsByMonth(
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final lessons = await _client
        .from('lessons')
        .select('duration, amount')
        .gte('start_date_time', start)
        .lt('start_date_time', end);
    return _aggregateLessons(lessons);
  }

  Map<String, dynamic> _aggregateLessons(List<dynamic> lessons) {
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
    return {'total_hours': totalHours, 'total_amount': totalAmount};
  }
}
