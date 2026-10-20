import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/notification_model.dart';

/// Bildirimler için Supabase Realtime erişimi.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Kullanıcının bildirimlerini canlı olarak dinler.
  Stream<List<AppNotification>> watch() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }
}
