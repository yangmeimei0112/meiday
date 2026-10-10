import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';

@immutable
class EventComment {
  final String id;
  final String eventId;
  final String userId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isPendingSync;

  const EventComment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isPendingSync = false,
  });

  EventComment copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? authorName,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isPendingSync,
  }) {
    return EventComment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  factory EventComment.fromData(EventCommentData data, {bool isPendingSync = false}) {
    return EventComment(
      id: data.id,
      eventId: data.eventId,
      userId: data.userId,
      authorName: data.authorName,
      content: data.content,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      isDeleted: data.isDeleted,
      isPendingSync: isPendingSync,
    );
  }

  EventCommentsCompanion toCompanion() {
    return EventCommentsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      userId: Value(userId),
      authorName: Value(authorName),
      content: Value(content),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'user_id': userId,
    'author_name': authorName,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventComment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
