import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI ile görev önceliklendirme sonucu.
class TaskAiResult {
  TaskAiResult({
    required this.priority,
    required this.reason,
    this.suggestedSubtasks = const [],
  });

  final int priority; // 1-5
  final String reason;
  final List<String> suggestedSubtasks;

  factory TaskAiResult.fallback() =>
      TaskAiResult(priority: 3, reason: '', suggestedSubtasks: const []);
}

/// AI ile günlük planlama sonucu.
class DailyPlanResult {
  DailyPlanResult({required this.summary, required this.items});

  final String summary;
  final List<PlanItem> items;

  factory DailyPlanResult.fallback() =>
      DailyPlanResult(summary: '', items: const []);
}

class PlanItem {
  PlanItem({required this.time, required this.title, this.note});

  final String time; // "09:00-10:30"
  final String title;
  final String? note;
}

/// AI istekleri Supabase Edge Function (`ai`) üzerinden giderek
/// Gemini API anahtarının istemcide sızmasını engeller.
class GeminiService {
  GeminiService(this._client, {Logger? logger}) : _logger = logger ?? Logger();

  final SupabaseClient _client;
  final Logger _logger;

  bool _isTurkish(String languageCode) => languageCode == 'tr';

  /// Edge Function'a prompt gönderir, metin yanıtı döndürür.
  Future<String> generateText(
    String prompt, {
    required String languageCode,
  }) async {
    final res = await _client.functions.invoke(
      'ai',
      body: {
        'prompt': prompt,
        'language': _isTurkish(languageCode) ? 'tr' : 'en',
      },
    );
    final data = res.data;

    Map<String, dynamic> map;
    if (data is String) {
      map = jsonDecode(data) as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      map = data;
    } else {
      return '';
    }
    final finishReason = map['finishReason'] as String?;
    if (finishReason != null && finishReason != 'STOP') {
      _logger.w('AI yanıtı tamamlanmadı: $finishReason');
    }
    return (map['text'] as String?)?.trim() ?? '';
  }

  /// Görev başlık/açıklamasına göre öncelik + alt görev önerir.
  Future<TaskAiResult> analyzeTask({
    required String title,
    String description = '',
    DateTime? dueDate,
    required String languageCode,
  }) async {
    final language = _isTurkish(languageCode) ? 'Turkish' : 'English';
    final prompt =
        '''
Analyze the task below and return ONLY valid JSON.
JSON format:
{"priority": 1-5, "reason": "short explanation", "subtasks": ["subtask 1", "subtask 2"]}

Rules:
- priority: integer from 1 (very low) to 5 (urgent/very important).
- reason: one short sentence in $language.
- subtasks: at most 5 actionable, short items in $language.
- All user-facing text must be in $language.

Task title: $title
Description: ${description.isEmpty ? 'None' : description}
Due date: ${dueDate?.toIso8601String() ?? 'None'}
''';

    try {
      final raw = await generateText(prompt, languageCode: languageCode);
      final map = _parseJson(raw);
      return TaskAiResult(
        priority: _clampPriority((map['priority'] as num?)?.toInt() ?? 3),
        reason: (map['reason'] as String?) ?? '',
        suggestedSubtasks: ((map['subtasks'] as List?) ?? const [])
            .cast<String>(),
      );
    } catch (e) {
      _logger.w('Task analizi başarısız: $e');
      return TaskAiResult.fallback();
    }
  }

  /// Görevlere göre günlük plan üretir.
  Future<DailyPlanResult> buildDailyPlan({
    required DateTime date,
    required List<String> pendingTasks,
    required List<String> completedToday,
    required List<String> existingEvents,
    required int freeHours,
    required String languageCode,
  }) async {
    final language = _isTurkish(languageCode) ? 'Turkish' : 'English';
    final dateIso = date.toIso8601String().split('T').first;
    final prompt =
        '''
Create a realistic daily schedule for $dateIso. Return ONLY valid JSON.
JSON format:
{"summary": "short summary", "items": [{"time": "09:00-10:30", "title": "activity", "note": "optional short note"}]}

User's situation:
- Pending tasks: ${pendingTasks.isEmpty ? 'None' : pendingTasks.join(', ')}
- Completed today: ${completedToday.isEmpty ? 'None' : completedToday.join(', ')}
- Existing calendar events: ${existingEvents.isEmpty ? 'None' : existingEvents.join(' | ')}
- Free hours available: $freeHours

Rules:
- Produce 4-6 items between 08:00 and 20:00, including short breaks.
- Do not overlap existing calendar events.
- Use 24-hour "HH:mm-HH:mm" time ranges, in chronological order.
- Prioritize pending tasks; leave at least 1-2 hours of buffer.
- Keep blocks between 30 and 120 minutes.
- summary: at most 2 sentences.
- All user-facing text must be in $language.
- Never use markdown or code fences.
''';

    try {
      final raw = await generateText(prompt, languageCode: languageCode);
      final map = _parseJson(raw);
      final items = <PlanItem>[];
      for (final entry in (map['items'] as List?) ?? const []) {
        if (entry is! Map) continue;
        final item = PlanItem(
          time: (entry['time'] as String?)?.trim() ?? '',
          title: (entry['title'] as String?)?.trim() ?? '',
          note: (entry['note'] as String?)?.trim(),
        );
        if (item.time.isEmpty || item.title.isEmpty) continue;
        items.add(item);
      }
      return DailyPlanResult(
        summary: (map['summary'] as String?)?.trim() ?? '',
        items: items,
      );
    } catch (e) {
      _logger.w('Günlük plan başarısız: $e');
      return DailyPlanResult.fallback();
    }
  }

  /// Gemini yanıtındaki olası markdown kod bloğunu temizleyip JSON'a çevirir.
  /// Yanıt MAX_TOKENS nedeniyle yarıda kaldıysa açık string/parantezleri
  /// kapatarak kurtarmayı dener.
  Map<String, dynamic> _parseJson(String raw) {
    var text = raw
        .replaceAll(RegExp(r'```[a-zA-Z]*\s*'), '')
        .replaceAll('```', '')
        .trim();
    final start = text.indexOf('{');
    if (start > 0) text = text.substring(start);

    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final end = text.lastIndexOf('}');
      if (end > 0) {
        try {
          return jsonDecode(text.substring(0, end + 1)) as Map<String, dynamic>;
        } catch (_) {}
      }
      final repaired = _repairJson(text);
      return jsonDecode(repaired) as Map<String, dynamic>;
    }
  }

  String _repairJson(String input) {
    final buffer = StringBuffer();
    final stack = <String>[];
    var inString = false;
    var escaped = false;

    for (final char in input.split('')) {
      buffer.write(char);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{' || char == '[') {
        stack.add(char);
      } else if (char == '}' || char == ']') {
        if (stack.isNotEmpty) stack.removeLast();
      }
    }

    var text = buffer.toString();
    if (escaped) text = text.substring(0, text.length - 1);
    if (inString) text = '$text"';
    text = text.trimRight();
    if (text.endsWith(',')) {
      text = text.substring(0, text.length - 1);
    } else if (text.endsWith(':')) {
      text = '$text null';
    }
    for (final open in stack.reversed) {
      text += open == '{' ? '}' : ']';
    }
    return text;
  }

  int _clampPriority(int value) => value.clamp(1, 5);
}
