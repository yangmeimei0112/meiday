import '../entities/event_comment.dart';

abstract class CommentRepository {
  /// Reactive stream of comments for an event in chronological order.
  Stream<List<EventComment>> watchComments(String eventId);

  /// Get comments for an event once.
  Future<List<EventComment>> getComments(String eventId);

  /// Post a new comment with offline-first local write and outbox queueing.
  Future<EventComment> postComment({
    required String eventId,
    required String content,
    required String authorName,
    required String userId,
  });

  /// Update an existing comment content.
  Future<void> updateComment({
    required String commentId,
    required String content,
    required String userId,
  });

  /// Soft-delete a comment.
  Future<void> deleteComment({
    required String commentId,
    required String userId,
  });
}
