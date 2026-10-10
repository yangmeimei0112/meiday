import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/event_attachment.dart';
import '../../domain/repositories/attachment_repository.dart';

class AttachmentRepositoryImpl implements AttachmentRepository {
  final AppDatabase database;

  AttachmentRepositoryImpl({required this.database});

  @override
  String getThumbnailPath(String attachmentId) {
    return 'attachments/thumbnails/thumb_$attachmentId.jpg';
  }

  @override
  String getLocalFilePath(String eventId, String attachmentId, String extension) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    return 'attachments/$eventId/$attachmentId.$cleanExt';
  }

  @override
  Stream<List<EventAttachment>> watchAttachments(String eventId) {
    return (database.select(database.eventAttachments)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch()
        .map((rows) => rows.map((r) => EventAttachment.fromData(r, thumbnailPath: getThumbnailPath(r.id))).toList());
  }

  @override
  Future<List<EventAttachment>> getAttachments(String eventId) async {
    final rows = await (database.select(database.eventAttachments)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return rows.map((r) => EventAttachment.fromData(r, thumbnailPath: getThumbnailPath(r.id))).toList();
  }

  @override
  Future<EventAttachment> addAttachment({
    required String eventId,
    required String userId,
    required String fileName,
    required String fileUrl,
    required String fileType,
    required int fileSize,
  }) async {
    final id = UuidUtils.generate();
    final now = DateTime.now();

    final attachment = EventAttachment(
      id: id,
      eventId: eventId,
      userId: userId,
      fileName: fileName,
      fileUrl: fileUrl,
      fileType: fileType,
      fileSize: fileSize,
      thumbnailPath: getThumbnailPath(id),
      createdAt: now,
    );

    await database.transaction(() async {
      await database.into(database.eventAttachments).insert(attachment.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventAttachments,
        recordId: id,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode(attachment.toJson()),
      );
    });

    return attachment;
  }

  @override
  Future<void> deleteAttachment({
    required String attachmentId,
    required String userId,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await (database.delete(database.eventAttachments)..where((t) => t.id.equals(attachmentId))).go();

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventAttachments,
        recordId: attachmentId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': attachmentId,
          'is_deleted': true,
          'deleted_at': now.toIso8601String(),
        }),
      );
    });
  }
}
