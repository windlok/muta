import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/language_store.dart';
import '../../../core/network/gemini_service.dart';
import '../../../core/providers/providers.dart';
import '../domain/task_model.dart';
import '../data/tasks_repository.dart';

/// Görev listesi ve aksiyonları.
class TasksViewModel extends AsyncNotifier<List<Task>> {
  late TasksRepository _repo;
  late GeminiService _gemini;

  @override
  Future<List<Task>> build() async {
    _repo = ref.watch(tasksRepositoryProvider);
    _gemini = ref.watch(geminiServiceProvider);

    // Kullanıcı değişince listeyi yeniden yükle; çıkışta listeyi temizle.
    ref.listen(authStateProvider, (prev, next) {
      final prevId = prev?.value?.session?.user.id;
      final nextId = next.value?.session?.user.id;
      if (nextId == null) {
        state = const AsyncData([]);
      } else if (prevId != nextId) {
        load();
      }
    });

    return _repo.fetchTasks();
  }

  Future<void> load() async {
    // Mevcut liste varsa koru (yenilemede ekran boşalmasın).
    if (!state.hasValue) state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchTasks);
  }

  Future<Task> addTask({
    required String title,
    String description = '',
    DateTime? dueDate,
    bool aiAnalyze = false,
  }) async {
    final uid = ref.read(currentUserIdProvider);
    final now = DateTime.now();

    var priority = 3;
    String? suggestion;
    List<String> subtasks = const [];

    if (aiAnalyze) {
      final result = await _gemini.analyzeTask(
        title: title,
        description: description,
        dueDate: dueDate,
        languageCode: ref.read(appLanguageProvider),
      );
      priority = result.priority;
      suggestion = result.reason.isEmpty ? null : result.reason;
      subtasks = result.suggestedSubtasks;
    }

    final task = Task(
      id: '',
      userId: uid ?? '',
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      aiSuggestion: suggestion,
      createdAt: now,
      updatedAt: now,
    );

    final saved = await _repo.addTask(task);
    state = AsyncData([saved, ...?state.value]);

    // AI alt görev önerilerini otomatik ekle.
    for (final sub in subtasks) {
      await _repo.addTask(
        Task(
          id: '',
          userId: uid ?? '',
          title: sub,
          priority: priority,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    if (subtasks.isNotEmpty) await load();
    return saved;
  }

  Future<void> toggle(Task task) async {
    final updated = task.copyWith(
      status: task.isDone ? TaskStatus.pending : TaskStatus.completed,
      updatedAt: DateTime.now(),
    );
    await _repo.updateTask(updated);
    _replace(updated);
  }

  Future<void> delete(Task task) async {
    await _repo.deleteTask(task.id);
    state = AsyncData(
      (state.value ?? []).where((t) => t.id != task.id).toList(),
    );
  }

  /// Bugünün planı için: bekleyen ve bugün tamamlanan başlıklar.
  List<String> get pendingTitles =>
      (state.value ?? []).where((t) => !t.isDone).map((t) => t.title).toList();

  List<String> get completedTitles =>
      (state.value ?? []).where((t) => t.isDone).map((t) => t.title).toList();

  void _replace(Task updated) {
    state = AsyncData([
      for (final t in state.value ?? [])
        if (t.id == updated.id) updated else t,
    ]);
  }
}

final tasksViewModelProvider =
    AsyncNotifierProvider<TasksViewModel, List<Task>>(TasksViewModel.new);
