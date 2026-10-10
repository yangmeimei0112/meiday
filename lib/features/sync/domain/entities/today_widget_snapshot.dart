import 'dart:convert';

class TodayWidgetEventItem {
  final String id;
  final String title;
  final String startTime;
  final String endTime;
  final bool isAllDay;
  final bool isAnchored;
  final int? color;

  const TodayWidgetEventItem({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.isAnchored,
    this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start_time': startTime,
        'end_time': endTime,
        'is_all_day': isAllDay,
        'is_anchored': isAnchored,
        'color': color,
      };

  factory TodayWidgetEventItem.fromJson(Map<String, dynamic> json) {
    return TodayWidgetEventItem(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isAllDay: json['is_all_day'] as bool? ?? false,
      isAnchored: json['is_anchored'] as bool? ?? false,
      color: json['color'] as int?,
    );
  }
}

class TodayWidgetTaskItem {
  final String id;
  final String title;
  final bool isCompleted;
  final int priority;

  const TodayWidgetTaskItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'is_completed': isCompleted,
        'priority': priority,
      };

  factory TodayWidgetTaskItem.fromJson(Map<String, dynamic> json) {
    return TodayWidgetTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
    );
  }
}

class TodayWidgetSnapshot {
  final String dateIso;
  final List<TodayWidgetEventItem> events;
  final List<TodayWidgetTaskItem> topTasks;
  final double capacityHours;
  final int totalFocusMinutes;
  final DateTime generatedAt;

  const TodayWidgetSnapshot({
    required this.dateIso,
    required this.events,
    required this.topTasks,
    required this.capacityHours,
    required this.totalFocusMinutes,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'date': dateIso,
        'events': events.map((e) => e.toJson()).toList(),
        'top_tasks': topTasks.map((t) => t.toJson()).toList(),
        'capacity_hours': capacityHours,
        'total_focus_minutes': totalFocusMinutes,
        'generated_at': generatedAt.toIso8601String(),
      };

  factory TodayWidgetSnapshot.fromJson(Map<String, dynamic> json) {
    return TodayWidgetSnapshot(
      dateIso: json['date'] as String,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => TodayWidgetEventItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topTasks: (json['top_tasks'] as List<dynamic>? ?? [])
          .map((t) => TodayWidgetTaskItem.fromJson(t as Map<String, dynamic>))
          .toList(),
      capacityHours: (json['capacity_hours'] as num?)?.toDouble() ?? 0.0,
      totalFocusMinutes: json['total_focus_minutes'] as int? ?? 0,
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  /// Estimates byte size of snapshot in UTF-8
  int get byteSize {
    final encoded = jsonEncode(toJson());
    return utf8.encode(encoded).length;
  }

  /// Invariant check: Snapshot must strictly stay well under 5MB (usually < 100KB)
  bool get isWithinSizeLimit => byteSize < 5 * 1024 * 1024;
}
