import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/formatters.dart';
import '../domain/notification_model.dart';

/// AppBar'da gösterilen bildirim zili + okunmamış sayacı.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(notificationsStreamProvider);
    final items = async.value ?? [];
    final unread = items.where((n) => !n.isRead).length;

    return IconButton(
      tooltip: l.notifications,
      onPressed: () => _openSheet(context),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => _NotificationsSheet(controller: controller),
      ),
    );
  }
}

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(notificationsStreamProvider);
    final items = async.value ?? [];
    final hasUnread = items.any((n) => !n.isRead);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.notifications,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: hasUnread
                    ? () => ref
                        .read(notificationsRepositoryProvider)
                        .markAllRead()
                    : null,
                child: Text(l.markAllRead),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: Builder(
            builder: (context) {
              if (async.isLoading && !async.hasValue) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 40, color: scheme.outline),
                      const SizedBox(height: 10),
                      Text(
                        l.noNotifications,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.priceDropsHere,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (context, i) => _NotificationTile(
                  notification: items[i],
                  onTap: items[i].isRead
                      ? null
                      : () => ref
                          .read(notificationsRepositoryProvider)
                          .markRead(items[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final unread = !notification.isRead;
    final isPrice = notification.type == 'price_alert';

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (unread ? scheme.primary : scheme.surfaceContainerHighest)
              .withValues(alpha: unread ? 0.14 : 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPrice ? Icons.trending_down : Icons.notifications_active_outlined,
          size: 20,
          color: unread ? scheme.primary : scheme.outline,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      subtitle: notification.body == null
          ? null
          : Text(notification.body!, maxLines: 2),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeLabel(l, notification.createdAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          if (unread) ...[
            const SizedBox(height: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeLabel(AppLocalizations l, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final time = formatTime(d);
    if (diff == 0) return l.timeToday(time);
    if (diff == 1) return l.timeYesterday(time);
    return '${l.dateShort(d)} $time';
  }
}
