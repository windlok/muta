/// Takvim etkinliği türleri.
enum EventType { task, appointment, reminder }

extension EventTypeX on EventType {
  String get label => switch (this) {
        EventType.task => 'Görev',
        EventType.appointment => 'Randevu',
        EventType.reminder => 'Hatırlatma',
      };

  String get wire => switch (this) {
        EventType.task => 'task',
        EventType.appointment => 'appointment',
        EventType.reminder => 'reminder',
      };

  static EventType fromWire(String value) => switch (value) {
        'appointment' => EventType.appointment,
        'reminder' => EventType.reminder,
        _ => EventType.task,
      };
}

/// Takvim etkinliği.
class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.type = EventType.reminder,
    this.aiGenerated = false,
    this.linkedTaskId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final EventType type;
  final bool aiGenerated;
  final String? linkedTaskId;
  final DateTime createdAt;

  bool get isPast => end.isBefore(DateTime.now());

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'title': title,
        'description': description,
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
        'event_type': type.wire,
        'ai_generated': aiGenerated,
        'linked_task_id': linkedTaskId,
      };

  factory CalendarEvent.fromMap(Map<String, dynamic> map) => CalendarEvent(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        start: DateTime.parse(map['start_time'] as String).toLocal(),
        end: DateTime.parse(map['end_time'] as String).toLocal(),
        type: EventTypeX.fromWire((map['event_type'] as String?) ?? 'reminder'),
        aiGenerated: (map['ai_generated'] as bool?) ?? false,
        linkedTaskId: map['linked_task_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
