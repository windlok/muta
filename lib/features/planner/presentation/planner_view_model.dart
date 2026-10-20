import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/language_store.dart';
import '../../../core/network/gemini_service.dart';
import '../../../core/providers/providers.dart';
import '../data/planner_repository.dart';
import '../domain/calendar_event_model.dart';

/// Takvim etkinlikleri + AI planlama.
class PlannerViewModel extends AsyncNotifier<List<CalendarEvent>> {
  late PlannerRepository _repo;
  late GeminiService _gemini;

  @override
  Future<List<CalendarEvent>> build() async {
    _repo = ref.watch(plannerRepositoryProvider);
    _gemini = ref.watch(geminiServiceProvider);
    ref.listen(authStateProvider, (prev, next) {
      final prevId = prev?.value?.session?.user.id;
      final nextId = next.value?.session?.user.id;
      if (nextId == null) {
        state = const AsyncData([]);
      } else if (prevId != nextId) {
        load();
      }
    });
    return _repo.fetchEvents();
  }

  Future<void> load() async {
    if (!state.hasValue) state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchEvents);
  }

  Future<void> add(CalendarEvent event) async {
    final saved = await _repo.addEvent(event);
    final list = <CalendarEvent>[...?state.value, saved]
      ..sort((a, b) => a.start.compareTo(b.start));
    state = AsyncData(list);
  }

  Future<void> delete(CalendarEvent event) async {
    await _repo.deleteEvent(event.id);
    state = AsyncData(
      (state.value ?? []).where((e) => e.id != event.id).toList(),
    );
  }

  /// Görevlerden AI ile günlük plan üretir.
  Future<DailyPlanResult> generatePlan({
    required DateTime date,
    required List<String> pendingTasks,
    required List<String> completedToday,
    required List<String> existingEvents,
    required int freeHours,
  }) async {
    try {
      return await _gemini.buildDailyPlan(
        date: date,
        pendingTasks: pendingTasks,
        completedToday: completedToday,
        existingEvents: existingEvents,
        freeHours: freeHours,
        languageCode: ref.read(appLanguageProvider),
      );
    } catch (_) {
      return DailyPlanResult.fallback();
    }
  }
}

final plannerViewModelProvider =
    AsyncNotifierProvider<PlannerViewModel, List<CalendarEvent>>(
      PlannerViewModel.new,
    );

/// Haftanın günlerine göre etkinlikleri gruplar.
Map<int, List<CalendarEvent>> groupByDay(List<CalendarEvent> events) {
  final map = <int, List<CalendarEvent>>{};
  for (final e in events) {
    map.putIfAbsent(e.start.weekday, () => []).add(e);
  }
  return map;
}
