import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';

@immutable
class EventAttachment {
  final String id;
  final String eventId;
  final String userId;
  final String fileName;
  final String fileUrl; // Local relative path or remote URL
  final String fileType; // MIME type, e.g. 'image/jpeg', 'image/png'
  final int fileSize; // bytes
  final String? thumbnailPath;
  final DateTime createdAt;

  const EventAttachment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    this.thumbnailPath,
    required this.createdAt,
  });

  bool get isImage =>
      fileType.startsWith('image/') ||
      fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png') ||
      fileName.endsWith('.webp');

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  EventAttachment copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? fileName,
    String? fileUrl,
    String? fileType,
    int? fileSize,
    String? thumbnailPath,
    DateTime? createdAt,
  }) {
    return EventAttachment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EventAttachment.fromData(EventAttachmentData data, {String? thumbnailPath}) {
    return EventAttachment(
      id: data.id,
      eventId: data.eventId,
      userId: data.userId,
      fileName: data.fileName,
      fileUrl: data.fileUrl,
      fileType: data.fileType,
      fileSize: data.fileSize,
      thumbnailPath: thumbnailPath,
      createdAt: data.createdAt,
    );
  }

  EventAttachmentsCompanion toCompanion() {
    return EventAttachmentsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      userId: Value(userId),
      fileName: Value(fileName),
      fileUrl: Value(fileUrl),
      fileType: Value(fileType),
      fileSize: Value(fileSize),
      createdAt: Value(createdAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'user_id': userId,
    'file_name': fileName,
    'file_url': fileUrl,
    'file_type': fileType,
    'file_size': fileSize,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAttachment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
