import '../entities/event_attachment.dart';

abstract class AttachmentRepository {
  /// Stream of attachments for an event.
  Stream<List<EventAttachment>> watchAttachments(String eventId);

  /// Get attachments for an event once.
  Future<List<EventAttachment>> getAttachments(String eventId);

  /// Add an attachment metadata, save file/thumbnail path reference, and enqueue outbox.
  Future<EventAttachment> addAttachment({
    required String eventId,
    required String userId,
    required String fileName,
    required String fileUrl,
    required String fileType,
    required int fileSize,
  });

  /// Delete an attachment record and enqueue outbox mutation.
  Future<void> deleteAttachment({
    required String attachmentId,
    required String userId,
  });

  /// Compute deterministic thumbnail path for an attachment.
  String getThumbnailPath(String attachmentId);

  /// Compute local storage path for an attachment under attachments/[eventId]/.
  String getLocalFilePath(String eventId, String attachmentId, String extension);
}
