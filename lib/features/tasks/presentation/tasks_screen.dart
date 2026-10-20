import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/task_model.dart';
import '../../notifications/presentation/notification_bell.dart';
import 'add_task_sheet.dart';
import 'tasks_view_model.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asyncTasks = ref.watch(tasksViewModelProvider);

    final all = asyncTasks.value ?? [];
    final filtered = switch (_filter) {
      _TaskFilter.all => all,
      _TaskFilter.pending => all.where((t) => !t.isDone).toList(),
      _TaskFilter.completed => all.where((t) => t.isDone).toList(),
    };

    final pendingCount = all.where((t) => !t.isDone).length;
    final doneCount = all.length - pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tasksTitle),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const AddTaskSheet(),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.addTask),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(tasksViewModelProvider.notifier).load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _TodaySummary(pending: pendingCount, done: doneCount),
              const SizedBox(height: 16),
              SegmentedButton<_TaskFilter>(
                segments: [
                  ButtonSegment(value: _TaskFilter.all, label: Text(l.all)),
                  ButtonSegment(value: _TaskFilter.pending, label: Text(l.active)),
                  ButtonSegment(
                      value: _TaskFilter.completed, label: Text(l.completed)),
                ],
                selected: {_filter},
                onSelectionChanged: (s) =>
                    setState(() => _filter = s.first),
              ),
              const SizedBox(height: 16),
              if (asyncTasks.isLoading && all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.task_alt,
                  title: _filter == _TaskFilter.completed
                      ? l.noCompletedTasksTitle
                      : l.noTasksTitle,
                  message: _filter == _TaskFilter.completed
                      ? l.completedTasksHere
                      : l.addFirstTask,
                )
              else
                ...filtered.map((task) => _TaskCard(task: task)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskFilter { all, pending, completed }

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final vm = ref.read(tasksViewModelProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => vm.toggle(task),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.isDone ? Colors.green : scheme.outline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isDone ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (task.aiSuggestion != null &&
                          task.aiSuggestion!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 14, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.aiSuggestion!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PriorityBadge(priority: task.priority),
                          if (task.dueDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.event,
                                size: 14, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _formatDue(l, task.dueDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isOverdue
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => _confirmDelete(context, ref, l, task),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    Task task,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTaskTitle),
        content: Text(l.deleteTaskConfirm(task.title)),
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
    if (ok == true) {
      await ref.read(tasksViewModelProvider.notifier).delete(task);
    }
  }

  String _formatDue(AppLocalizations l, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(d.year, d.month, d.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return l.today;
    if (diff == 1) return l.tomorrow;
    if (diff < 0) return l.overdue;
    return l.dateShort(d);
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.pending, required this.done});

  final int pending;
  final int done;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final total = pending + done;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dateLong(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.pendingDoneSummary(pending, done),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: scheme.primary,
                    backgroundColor:
                        scheme.surface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            height: 62,
            width: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 62,
                  width: 62,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: scheme.primary,
                    backgroundColor:
                        scheme.surface.withValues(alpha: 0.55),
                  ),
                ),
                Text(
                  '%${(progress * 100).round()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.priorityColor(scheme, priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        l.priorityLabel(priority),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
