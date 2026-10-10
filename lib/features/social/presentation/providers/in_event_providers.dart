import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/event_attachment.dart';
import '../../domain/entities/event_checklist_item.dart';
import '../../domain/entities/event_comment.dart';
import '../../domain/repositories/attachment_repository.dart';
import '../../domain/repositories/checklist_repository.dart';
import '../../domain/repositories/comment_repository.dart';
import '../../data/repositories/attachment_repository_impl.dart';
import '../../data/repositories/checklist_repository_impl.dart';
import '../../data/repositories/comment_repository_impl.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CommentRepositoryImpl(database: db);
});

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AttachmentRepositoryImpl(database: db);
});

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChecklistRepositoryImpl(database: db);
});

final eventCommentsStreamProvider =
    StreamProvider.family<List<EventComment>, String>((ref, eventId) {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.watchComments(eventId);
});

final eventAttachmentsStreamProvider =
    StreamProvider.family<List<EventAttachment>, String>((ref, eventId) {
  final repo = ref.watch(attachmentRepositoryProvider);
  return repo.watchAttachments(eventId);
});

final eventChecklistStreamProvider =
    StreamProvider.family<List<EventChecklistItem>, String>((ref, eventId) {
  final repo = ref.watch(checklistRepositoryProvider);
  return repo.watchChecklist(eventId);
});
