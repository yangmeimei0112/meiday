import 'dart:convert';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/event_comment.dart';
import '../../domain/repositories/comment_repository.dart';

class CommentRepositoryImpl implements CommentRepository {
  final AppDatabase database;

  CommentRepositoryImpl({required this.database});

  @override
  Stream<List<EventComment>> watchComments(String eventId) {
    return database.commentDao.watchCommentsForEvent(eventId).map(
          (rows) => rows.map(EventComment.fromData).toList(),
        );
  }

  @override
  Future<List<EventComment>> getComments(String eventId) async {
    final rows = await database.commentDao.getCommentsForEvent(eventId);
    return rows.map(EventComment.fromData).toList();
  }

  @override
  Future<EventComment> postComment({
    required String eventId,
    required String content,
    required String authorName,
    required String userId,
  }) async {
    final id = UuidUtils.generate();
    final now = DateTime.now();

    final comment = EventComment(
      id: id,
      eventId: eventId,
      userId: userId,
      authorName: authorName,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    await database.transaction(() async {
      await database.commentDao.insertComment(comment.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventComments,
        recordId: id,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode(comment.toJson()),
      );
    });

    return comment;
  }

  @override
  Future<void> updateComment({
    required String commentId,
    required String content,
    required String userId,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.commentDao.updateComment(commentId, content);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventComments,
        recordId: commentId,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': commentId,
          'content': content,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.commentDao.deleteComment(commentId);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventComments,
        recordId: commentId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': commentId,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }
}
