/// Görev durumları.
enum TaskStatus { pending, inProgress, completed }

extension TaskStatusX on TaskStatus {
  String get label => switch (this) {
        TaskStatus.pending => 'Bekliyor',
        TaskStatus.inProgress => 'Devam Ediyor',
        TaskStatus.completed => 'Tamamlandı',
      };

  String get wire => switch (this) {
        TaskStatus.pending => 'pending',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.completed => 'completed',
      };

  static TaskStatus fromWire(String value) => switch (value) {
        'in_progress' => TaskStatus.inProgress,
        'completed' => TaskStatus.completed,
        _ => TaskStatus.pending,
      };
}

/// Tek bir görev.
class Task {
  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.priority = 3,
    this.status = TaskStatus.pending,
    this.dueDate,
    this.recurrence = 'none',
    this.aiSuggestion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final int priority; // 1-5
  final TaskStatus status;
  final DateTime? dueDate;
  final String recurrence; // none, daily, weekly, monthly
  final String? aiSuggestion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDone => status == TaskStatus.completed;

  /// Gün bazında gecikme: bugün teslimi olan görev gecikmiş sayılmaz.
  bool get isOverdue {
    if (isDone || dueDate == null) return false;
    final due = dueDate!;
    final now = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);
    return dueDay.isBefore(today);
  }

  Task copyWith({
    String? title,
    String? description,
    int? priority,
    TaskStatus? status,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? recurrence,
    String? aiSuggestion,
    bool clearAiSuggestion = false,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      recurrence: recurrence ?? this.recurrence,
      aiSuggestion:
          clearAiSuggestion ? null : (aiSuggestion ?? this.aiSuggestion),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priority,
        'status': status.wire,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'recurrence': recurrence,
        'ai_suggestion': aiSuggestion,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  /// Sadece yeni kayıt oluştururken kullanılır (id ve tarihler DB'den gelir).
  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priority,
        'status': status.wire,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'recurrence': recurrence,
        'ai_suggestion': aiSuggestion,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        priority: (map['priority'] as num?)?.toInt() ?? 3,
        status: TaskStatusX.fromWire((map['status'] as String?) ?? 'pending'),
        dueDate: map['due_date'] == null
            ? null
            : DateTime.parse(map['due_date'] as String).toLocal(),
        recurrence: (map['recurrence'] as String?) ?? 'none',
        aiSuggestion: map['ai_suggestion'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );
}
