import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/gemini_service.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../tasks/presentation/tasks_view_model.dart';
import '../domain/calendar_event_model.dart';
import 'planner_view_model.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _selected = DateTime.now();
  Timer? _clock;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  bool get _isToday => _sameDay(_selected, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asyncEvents = ref.watch(plannerViewModelProvider);
    final events = asyncEvents.value ?? [];
    final dayEvents = _eventsForDay(events, _selected);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.planTitle),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: l.aiPlan,
            onPressed: _generating ? null : _generatePlan,
            icon: _generating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEvent,
        icon: const Icon(Icons.add),
        label: Text(l.addEvent),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _WeekHeader(
              selected: _selected,
              count: dayEvents.length,
              isToday: _isToday,
              onPrev: _shiftWeek(-7),
              onNext: _shiftWeek(7),
              onToday: () => setState(() => _selected = DateTime.now()),
            ),
            _WeekStrip(
              selected: _selected,
              events: events,
              onSelect: (d) => setState(() => _selected = d),
            ),
            const Divider(height: 1),
            Expanded(
              child: asyncEvents.isLoading && events.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        children: [
                          if (dayEvents.isEmpty)
                            _EmptyDayCard(
                              onAdd: _addEvent,
                              onAiPlan: _generatePlan,
                            ),
                          _DayTimeline(
                            day: _selected,
                            events: dayEvents,
                            onTap: _showEventDetails,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback _shiftWeek(int days) => () {
    setState(() {
      _selected = _selected.add(Duration(days: days));
    });
  };

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime day) {
    return events.where((e) => _sameDay(e.start, day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _generatePlan() async {
    if (_generating) return;
    final l = AppLocalizations.of(context);
    final tasks = ref.read(tasksViewModelProvider).value ?? [];
    final vm = ref.read(plannerViewModelProvider.notifier);
    final events = ref.read(plannerViewModelProvider).value ?? [];
    final dayEvents = _eventsForDay(events, _selected);
    final pending = tasks.where((t) => !t.isDone).map((t) => t.title).toList();
    final completed = tasks
        .where((t) => t.isDone && _sameDay(t.updatedAt, _selected))
        .map((t) => t.title)
        .toList();

    final windowStart = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
      8,
    );
    final windowEnd = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
      20,
    );
    var busyMinutes = 0;
    for (final event in dayEvents) {
      final start = event.start.isBefore(windowStart)
          ? windowStart
          : event.start;
      final end = event.end.isAfter(windowEnd) ? windowEnd : event.end;
      if (end.isAfter(start)) {
        busyMinutes += end.difference(start).inMinutes;
      }
    }
    final freeHours = ((720 - busyMinutes) / 60).clamp(1, 12).round();

    setState(() => _generating = true);
    final result = await vm.generatePlan(
      date: _selected,
      pendingTasks: pending,
      completedToday: completed,
      existingEvents: [
        for (final event in dayEvents)
          '${_hhmm(event.start)}-${_hhmm(event.end)} ${event.title}',
      ],
      freeHours: freeHours,
    );
    if (!mounted) return;
    setState(() => _generating = false);

    if (result.items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.aiPlanFailed)));
      return;
    }

    final selected = await showModalBottomSheet<List<PlanItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanSheet(result: result),
    );
    if (!mounted || selected == null || selected.isEmpty) return;

    final newEvents = <CalendarEvent>[
      for (final item in selected) _eventFromPlanItem(item, _selected),
    ];
    try {
      for (final event in newEvents) {
        await vm.add(event);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.eventsAdded(newEvents.length))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.eventAddFailed)));
      }
    }
  }

  CalendarEvent _eventFromPlanItem(PlanItem item, DateTime day) {
    final matches = RegExp(r'(\d{1,2}):(\d{2})').allMatches(item.time).toList();
    final start = matches.isEmpty
        ? DateTime(day.year, day.month, day.day, 9)
        : _timeOf(day, matches.first);
    var end = matches.length > 1
        ? _timeOf(day, matches[1])
        : start.add(const Duration(hours: 1));
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
    return CalendarEvent(
      id: '',
      userId: '',
      title: item.title,
      description: item.note,
      start: start,
      end: end,
      type: EventType.task,
      aiGenerated: true,
      createdAt: DateTime.now(),
    );
  }

  DateTime _timeOf(DateTime day, RegExpMatch match) {
    final hour = (int.tryParse(match.group(1) ?? '') ?? 9).clamp(0, 23);
    final minute = (int.tryParse(match.group(2) ?? '') ?? 0).clamp(0, 59);
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  String _hhmm(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  Future<void> _showEventDetails(CalendarEvent event) async {
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => _EventDetailsSheet(event: event),
    );
    if (delete == true) {
      await ref.read(plannerViewModelProvider.notifier).delete(event);
    }
  }

  Future<void> _addEvent() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddEventSheet(initialDate: _selected),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.selected,
    required this.count,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime selected;
  final int count;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dateLong(selected),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.eventCount(count),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.previousWeek,
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: l.nextWeek,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          if (!isToday) TextButton(onPressed: onToday, child: Text(l.today)),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selected,
    required this.events,
    required this.onSelect,
  });

  final DateTime selected;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final base = DateTime(selected.year, selected.month, selected.day);
    final startOfWeek = base.subtract(Duration(days: base.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final now = DateTime.now();
    final counts = <String, int>{};
    for (final event in events) {
      final key = _dayKey(event.start);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          final isSelected =
              day.day == selected.day && day.month == selected.month;
          final isToday =
              day.day == now.day &&
              day.month == now.month &&
              day.year == now.year;
          final count = counts[_dayKey(day)] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(day),
              child: Container(
                width: 54,
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l.weekdayShort(day),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? scheme.onPrimary
                            : isToday
                            ? scheme.primary
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var dot = 0; dot < count.clamp(0, 3); dot++)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? scheme.onPrimary
                                    : scheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _dayKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.onAdd, required this.onAiPlan});

  final VoidCallback onAdd;
  final VoidCallback onAiPlan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.noEventsTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.noEventsMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onAiPlan, child: Text(l.aiPlan)),
              TextButton(onPressed: onAdd, child: Text(l.add)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.day,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onTap;

  static const double _hourHeight = 76;
  static const double _gutter = 54;
  static const double _topPad = 10;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    var startMinutes = 8 * 60;
    var endMinutes = 20 * 60;
    for (final event in events) {
      startMinutes = startMinutes < _minutes(event.start)
          ? startMinutes
          : _minutes(event.start);
      endMinutes = endMinutes > _minutes(event.end)
          ? endMinutes
          : _minutes(event.end);
    }
    final startHour = (startMinutes ~/ 60).clamp(0, 23);
    final endHour = (endMinutes / 60).ceil().clamp(startHour + 1, 24);
    final totalHeight = (endHour - startHour) * _hourHeight;
    final placed = _layout(events);
    final now = DateTime.now();
    final showNow =
        now.year == day.year &&
        now.month == day.month &&
        now.day == day.day &&
        _minutes(now) >= startHour * 60 &&
        _minutes(now) <= endHour * 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - _gutter - 8;
        return SizedBox(
          height: totalHeight + _topPad * 2,
          child: Stack(
            children: [
              for (var hour = startHour; hour <= endHour; hour++)
                Positioned(
                  left: 0,
                  top: _topPad + (hour - startHour) * _hourHeight - 7,
                  width: _gutter - 8,
                  child: Text(
                    l.time(DateTime(2000, 1, 1, hour % 24)),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (var hour = startHour; hour < endHour; hour++) ...[
                Positioned(
                  left: _gutter,
                  right: 0,
                  top: _topPad + (hour - startHour) * _hourHeight,
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                Positioned(
                  left: _gutter,
                  right: 0,
                  top:
                      _topPad +
                      (hour - startHour) * _hourHeight +
                      _hourHeight / 2,
                  child: Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ],
              for (final item in placed)
                Positioned(
                  left: _gutter + 4 + contentWidth * item.column / item.columns,
                  width: contentWidth / item.columns - 4,
                  top:
                      _topPad +
                      (_minutes(item.event.start) - startHour * 60) *
                          _hourHeight /
                          60 +
                      1,
                  height:
                      ((item.event.end.difference(item.event.start).inMinutes) *
                              _hourHeight /
                              60)
                          .clamp(28, double.infinity),
                  child: _TimelineEventBlock(
                    event: item.event,
                    compact:
                        ((item.event.end
                                .difference(item.event.start)
                                .inMinutes) *
                            _hourHeight /
                            60) <
                        54,
                    onTap: () => onTap(item.event),
                  ),
                ),
              if (showNow)
                Positioned(
                  left: _gutter - 2,
                  right: 0,
                  top:
                      _topPad +
                      (_minutes(now) - startHour * 60) * _hourHeight / 60,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.error,
                        ),
                      ),
                      Expanded(
                        child: Container(height: 2, color: scheme.error),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _minutes(DateTime date) => date.hour * 60 + date.minute;

  List<_PlacedEvent> _layout(List<CalendarEvent> events) {
    final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
    final result = <_PlacedEvent>[];
    var cluster = <CalendarEvent>[];
    DateTime? clusterEnd;

    void flush() {
      if (cluster.isEmpty) return;
      final columnEnds = <int, DateTime>{};
      final assigned = <CalendarEvent, int>{};
      for (final event in cluster) {
        var column = 0;
        while (columnEnds[column] != null &&
            columnEnds[column]!.isAfter(event.start)) {
          column++;
        }
        columnEnds[column] = event.end;
        assigned[event] = column;
      }
      final columns = columnEnds.length;
      for (final event in cluster) {
        result.add(_PlacedEvent(event, assigned[event]!, columns));
      }
      cluster = <CalendarEvent>[];
      clusterEnd = null;
    }

    for (final event in sorted) {
      if (cluster.isNotEmpty &&
          clusterEnd != null &&
          !event.start.isBefore(clusterEnd!)) {
        flush();
      }
      cluster.add(event);
      if (clusterEnd == null || event.end.isAfter(clusterEnd!)) {
        clusterEnd = event.end;
      }
    }
    flush();
    return result;
  }
}

class _PlacedEvent {
  const _PlacedEvent(this.event, this.column, this.columns);

  final CalendarEvent event;
  final int column;
  final int columns;
}

class _TimelineEventBlock extends StatelessWidget {
  const _TimelineEventBlock({
    required this.event,
    required this.compact,
    required this.onTap,
  });

  final CalendarEvent event;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = switch (event.type) {
      EventType.task => scheme.primary,
      EventType.appointment => scheme.tertiary,
      EventType.reminder => scheme.secondary,
    };

    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(8, compact ? 4 : 6, 6, 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  '${l.time(event.start)} – ${l.time(event.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (event.end.difference(event.start).inMinutes >= 60)
                  Text(
                    l.eventTypeLabel(event.type.wire),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: color),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.result});

  final DailyPlanResult result;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final List<bool> _selected = List<bool>.filled(
    widget.result.items.length,
    true,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = _selected.where((selected) => selected).length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.aiDayPlan,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (widget.result.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.result.summary,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.result.items.length,
                  itemBuilder: (context, i) {
                    final item = widget.result.items[i];
                    return CheckboxListTile(
                      value: _selected[i],
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) =>
                          setState(() => _selected[i] = value ?? false),
                      title: Row(
                        children: [
                          SizedBox(
                            width: 86,
                            child: Text(
                              item.time,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: item.note == null || item.note!.isEmpty
                          ? null
                          : Text(
                              item.note!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: count == 0
                    ? null
                    : () {
                        final items = <PlanItem>[
                          for (var i = 0; i < _selected.length; i++)
                            if (_selected[i]) widget.result.items[i],
                        ];
                        Navigator.of(context).pop(items);
                      },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(l.addSelectedEvents(count)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  event.aiGenerated ? Icons.auto_awesome : Icons.event_note,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(l.eventTypeLabel(event.type.wire)),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('${l.time(event.start)} – ${l.time(event.end)}'),
                  visualDensity: VisualDensity.compact,
                ),
                if (event.aiGenerated)
                  Chip(
                    label: Text(l.aiGeneratedLabel),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l.dateLong(event.start),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(event.description!),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.deleteEventTitle),
                    content: Text(l.deleteEventConfirm(event.title)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              icon: Icon(Icons.delete_outline, color: scheme.error),
              label: Text(l.delete, style: TextStyle(color: scheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEventSheet extends ConsumerStatefulWidget {
  const _AddEventSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<_AddEventSheet> {
  final _title = TextEditingController();
  late DateTime _date = widget.initialDate;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  EventType _type = EventType.appointment;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.hour * 60 + _end.minute <= picked.hour * 60 + picked.minute) {
          final endMinutes = picked.hour * 60 + picked.minute + 60;
          _end = TimeOfDay(
            hour: (endMinutes ~/ 60) % 24,
            minute: endMinutes % 60,
          );
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.eventTitleRequired)));
      return;
    }
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _start.hour,
      _start.minute,
    );
    final end = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _end.hour,
      _end.minute,
    );
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.endAfterStart)));
      return;
    }
    final event = CalendarEvent(
      id: '',
      userId: '',
      title: _title.text.trim(),
      start: start,
      end: end,
      type: _type,
      createdAt: DateTime.now(),
    );

    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(plannerViewModelProvider.notifier);
    Navigator.of(context).pop();
    try {
      await viewModel.add(event);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.eventAddFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.newEvent,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.eventTitleLabel,
              hintText: l.eventTitleHint,
              prefixIcon: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(l.monthDayYear(_date)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.startLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _pickTime(start: true),
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        l.time(DateTime(0, 1, 1, _start.hour, _start.minute)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.endLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _pickTime(start: false),
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        l.time(DateTime(0, 1, 1, _end.hour, _end.minute)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in EventType.values)
                ChoiceChip(
                  label: Text(l.eventTypeLabel(type.wire)),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
