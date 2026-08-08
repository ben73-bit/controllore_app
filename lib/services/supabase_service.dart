import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/contract.dart';
import '../models/lesson.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static const Duration _timeout = Duration(seconds: 10);

  // --- Auth ---

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

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
        .limit(limit)
        .timeout(_timeout);
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

    final uuid = const Uuid();
    final items = lessons.map((l) {
      final map = <String, dynamic>{
        'id': uuid.v4(),
        'start_date_time': l.startDateTime.toUtc().toIso8601String(),
        'duration': l.duration,
        'is_confirmed': l.isConfirmed,
        'is_billed': l.isBilled,
      };
      if (l.contractId != null && l.contractId!.isNotEmpty) {
        map['contract_id'] = l.contractId;
      }
      if (l.summary != null) map['summary'] = l.summary;
      if (l.description != null) map['description'] = l.description;
      if (l.location != null) map['location'] = l.location;
      if (l.invoiceNumber != null) map['invoice_number'] = l.invoiceNumber;
      if (l.invoiceDate != null) {
        map['invoice_date'] = l.invoiceDate!.toUtc().toIso8601String();
      }
      if (l.amount != null) map['amount'] = l.amount;
      return map;
    }).toList();

    await _client.from('lessons').insert(items);
  }

  Future<void> deleteLesson(String lessonId) async {
    await _client.from('lessons').delete().eq('id', lessonId);
  }

  /// Elimina una lista di lezioni in blocco (Batch Delete).
  Future<void> deleteLessonsBatch(List<String> lessonIds) async {
    if (lessonIds.isEmpty) return;
    await _client.from('lessons').delete().inFilter('id', lessonIds);
  }

  /// Assegna un contratto ad una lista di lezioni ricalcolando l'importo.
  /// Esegue un'unica chiamata al database (Batch Update tramite Upsert).
  Future<void> assignContractToLessons({
    required List<Lesson> lessons,
    required Contract contract,
  }) async {
    if (lessons.isEmpty) return;

    final updates = lessons.map((l) {
      double? amount;
      final parts = l.duration.split(':');
      if (parts.length >= 2) {
        final hours =
            (int.tryParse(parts[0]) ?? 0) +
            (int.tryParse(parts[1]) ?? 0) / 60.0;
        amount = hours * contract.hourlyRate;
      }

      // Creiamo il JSON aggiornato partendo dalla lezione esistente
      final json = l.toJson();
      json['contract_id'] = contract.id;
      json['amount'] = amount;

      // Assicuriamoci che le date siano in formato stringa ISO per PostgreSQL
      json['start_date_time'] = l.startDateTime.toUtc().toIso8601String();
      if (l.invoiceDate != null) {
        json['invoice_date'] = l.invoiceDate!.toUtc().toIso8601String();
      }

      return json;
    }).toList();

    // Upsert aggiorna i record se l'ID è già presente
    await _client.from('lessons').upsert(updates);
  }

  /// Segna le lezioni selezionate come fatturate (Batch Update).
  Future<void> markLessonsAsBilled({
    required List<String> lessonIds,
    required String invoiceNumber,
    required DateTime invoiceDate,
  }) async {
    if (lessonIds.isEmpty) return;
    await _client
        .from('lessons')
        .update({
          'is_billed': true,
          'invoice_number': invoiceNumber,
          'invoice_date': invoiceDate.toIso8601String(),
        })
        .inFilter('id', lessonIds);
  }

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

  Future<List<Lesson>> getUnbilledLessons() async {
    final response = await _client
        .from('lessons')
        .select()
        .eq('is_billed', false)
        .order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  Future<List<Lesson>> getBilledLessons() async {
    final response = await _client
        .from('lessons')
        .select()
        .eq('is_billed', true)
        .order('invoice_date', ascending: false)
        .order('start_date_time', ascending: false);
    return (response as List).map((json) => Lesson.fromJson(json)).toList();
  }

  Future<List<Lesson>> getLessonsFiltered({
    String? contractId,
    DateTime? from,
    DateTime? to,
  }) async {
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

  Future<Map<String, dynamic>> getDashboardStats() async {
    final lessons = await _client
        .from('lessons')
        .select('duration, amount')
        .timeout(_timeout);
    return _aggregateLessons(lessons);
  }

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
        .lt('start_date_time', end)
        .timeout(_timeout);
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
