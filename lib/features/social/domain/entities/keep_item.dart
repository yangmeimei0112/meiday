import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';

enum KeepPriority {
  none(0),
  low(1),
  medium(2),
  high(3);

  final int value;
  const KeepPriority(this.value);

  static KeepPriority fromValue(int val) {
    return KeepPriority.values.firstWhere(
      (p) => p.value == val,
      orElse: () => KeepPriority.none,
    );
  }
}

@immutable
class KeepItem {
  final String id;
  final String userId;
  final String title;
  final String? notes; // Mapped to content in Drift
  final int? color;
  final List<String> tags;
  final KeepPriority priority;
  final String? convertedToEventId;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const KeepItem({
    required this.id,
    required this.userId,
    required this.title,
    this.notes,
    this.color,
    this.tags = const [],
    this.priority = KeepPriority.none,
    this.convertedToEventId,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get isConverted => convertedToEventId != null;

  KeepItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    int? color,
    List<String>? tags,
    KeepPriority? priority,
    String? convertedToEventId,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return KeepItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      color: color ?? this.color,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      convertedToEventId: convertedToEventId ?? this.convertedToEventId,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  factory KeepItem.fromData(KeepItemData data) {
    final parsedTags = <String>[];
    KeepPriority parsedPriority = KeepPriority.none;

    if (data.tags != null && data.tags!.isNotEmpty) {
      final rawTokens = data.tags!.split(',');
      for (final token in rawTokens) {
        final trimmed = token.trim();
        if (trimmed.startsWith('p:')) {
          final pVal = int.tryParse(trimmed.substring(2)) ?? 0;
          parsedPriority = KeepPriority.fromValue(pVal);
        } else if (trimmed.isNotEmpty) {
          parsedTags.add(trimmed);
        }
      }
    }

    return KeepItem(
      id: data.id,
      userId: data.userId,
      title: data.title,
      notes: data.content,
      color: data.color,
      tags: parsedTags,
      priority: parsedPriority,
      convertedToEventId: data.convertedToEventId,
      isArchived: data.isArchived,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      isDeleted: data.isDeleted,
    );
  }

  KeepItemsCompanion toCompanion() {
    final allTags = List<String>.from(tags);
    if (priority != KeepPriority.none) {
      allTags.add('p:${priority.value}');
    }

    return KeepItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      title: Value(title),
      content: Value(notes),
      color: Value(color),
      tags: Value(allTags.isEmpty ? null : allTags.join(',')),
      convertedToEventId: Value(convertedToEventId),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'content': notes,
    'color': color,
    'tags': tags,
    'priority': priority.value,
    'converted_to_event_id': convertedToEventId,
    'is_archived': isArchived,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeepItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
