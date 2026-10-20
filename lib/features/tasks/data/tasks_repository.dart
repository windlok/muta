import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/task_model.dart';

/// Görevler için Supabase veri erişimi.
class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<Task>> fetchTasks() async {
    final uid = _uid;
    if (uid == null) return [];
    final data = await _client
        .from('tasks')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Task.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Task> addTask(Task task) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı.');
    final row = await _client
        .from('tasks')
        .insert({
          ...task.toInsertMap(),
          'user_id': uid,
        })
        .select()
        .single();
    return Task.fromMap(row);
  }

  Future<void> updateTask(Task task) async {
    await _client
        .from('tasks')
        .update(task.toMap()
          ..['updated_at'] = DateTime.now().toUtc().toIso8601String())
        .eq('id', task.id);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  /// Tekrarlanan görevleri bugün için yeniden oluşturur (gerekirse).
  Future<List<Task>> fetchRecurringTemplates() async {
    final uid = _uid;
    if (uid == null) return [];
    final data = await _client
        .from('tasks')
        .select()
        .eq('user_id', uid)
        .neq('recurrence', 'none');
    return (data as List)
        .map((e) => Task.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
