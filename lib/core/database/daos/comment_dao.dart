import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/event_comments_table.dart';

part 'comment_dao.g.dart';

@DriftAccessor(tables: [EventComments])
class CommentDao extends DatabaseAccessor<AppDatabase> with _$CommentDaoMixin {
  CommentDao(super.db);

  Stream<List<EventCommentData>> watchCommentsForEvent(String eventId) {
    return (select(eventComments)
          ..where((t) => t.eventId.equals(eventId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<int> insertComment(EventCommentsCompanion companion) {
    return into(eventComments).insert(companion);
  }

  Future<EventCommentData?> getCommentById(String id) {
    return (select(eventComments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<EventCommentData>> getCommentsForEvent(String eventId) {
    return (select(eventComments)
          ..where((t) => t.eventId.equals(eventId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<int> updateComment(String id, String content) {
    return (update(eventComments)..where((t) => t.id.equals(id))).write(
      EventCommentsCompanion(
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteComment(String id) {
    return (update(eventComments)..where((t) => t.id.equals(id))).write(
      EventCommentsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
