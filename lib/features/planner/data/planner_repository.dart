import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/calendar_event_model.dart';

/// Takvim etkinlikleri için Supabase veri erişimi.
class PlannerRepository {
  PlannerRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<CalendarEvent>> fetchEvents() async {
    final uid = _uid;
    if (uid == null) return [];
    final data = await _client
        .from('calendar_events')
        .select()
        .eq('user_id', uid)
        .order('start_time', ascending: true);
    return (data as List)
        .map((e) => CalendarEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> addEvent(CalendarEvent event) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı.');
    final row = await _client
        .from('calendar_events')
        .insert({
          ...event.toInsertMap(),
          'user_id': uid,
        })
        .select()
        .single();
    return CalendarEvent.fromMap(row);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('calendar_events').delete().eq('id', id);
  }

  /// Verilen tarih aralığındaki etkinlikleri getirir.
  Future<List<CalendarEvent>> fetchEventsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final uid = _uid;
    if (uid == null) return [];
    final data = await _client
        .from('calendar_events')
        .select()
        .eq('user_id', uid)
        .gte('start_time', start.toIso8601String())
        .lte('end_time', end.toIso8601String())
        .order('start_time', ascending: true);
    return (data as List)
        .map((e) => CalendarEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
