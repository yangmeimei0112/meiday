import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/comment_repository_impl.dart';

void main() {
  group('CommentRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late CommentRepositoryImpl repository;
    late String testEventId;

    setUp(() async {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_comments.db');
      database = AppDatabase(connection);
      repository = CommentRepositoryImpl(database: database);

      testEventId = UuidUtils.generate();
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: testEventId,
          userId: 'u1',
          title: '討論主題行程',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('postComment creates local comment and enqueues Outbox mutation', () async {
      final comment = await repository.postComment(
        eventId: testEventId,
        content: '記得準備會議投影片',
        authorName: 'Alice',
        userId: 'user_alice',
      );

      expect(comment.content, equals('記得準備會議投影片'));
      expect(comment.authorName, equals('Alice'));

      final list = await repository.getComments(testEventId);
      expect(list.length, equals(1));
      expect(list.first.id, equals(comment.id));

      final outbox = await database.outboxDao.getPendingMutations();
      final mutation = outbox.firstWhere(
        (m) => m.recordId == comment.id && m.targetTable == DbConstants.tableEventComments,
      );
      expect(mutation.action, equals(DbConstants.outboxActionInsert));
      expect(mutation.payloadJson, contains('記得準備會議投影片'));
    });

    test('watchComments streams comments in chronological order', () async {
      await repository.postComment(
        eventId: testEventId,
        content: '第一則發言',
        authorName: 'Bob',
        userId: 'user_bob',
      );

      // Brief delay to ensure chronological timestamp order
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await repository.postComment(
        eventId: testEventId,
        content: '第二則發言',
        authorName: 'Charlie',
        userId: 'user_charlie',
      );

      final comments = await repository.watchComments(testEventId).first;
      expect(comments.length, equals(2));
      expect(comments[0].content, equals('第一則發言'));
      expect(comments[1].content, equals('第二則發言'));
    });

    test('updateComment modifies content and enqueues UPDATE mutation', () async {
      final comment = await repository.postComment(
        eventId: testEventId,
        content: '原始文字',
        authorName: 'Dave',
        userId: 'user_dave',
      );

      await repository.updateComment(
        commentId: comment.id,
        content: '修改後的文字',
        userId: 'user_dave',
      );

      final list = await repository.getComments(testEventId);
      expect(list.first.content, equals('修改後的文字'));

      final outbox = await database.outboxDao.getPendingMutations();
      final updateMutation = outbox.firstWhere(
        (m) => m.recordId == comment.id && m.action == DbConstants.outboxActionUpdate,
      );
      expect(updateMutation.payloadJson, contains('修改後的文字'));
    });

    test('deleteComment performs soft deletion and enqueues DELETE mutation', () async {
      final comment = await repository.postComment(
        eventId: testEventId,
        content: '將被刪除的留言',
        authorName: 'Eve',
        userId: 'user_eve',
      );

      expect((await repository.getComments(testEventId)).length, equals(1));

      await repository.deleteComment(commentId: comment.id, userId: 'user_eve');

      // Soft-deleted comments should not appear in active comments
      final afterDelete = await repository.getComments(testEventId);
      expect(afterDelete, isEmpty);

      final outbox = await database.outboxDao.getPendingMutations();
      final deleteMutation = outbox.firstWhere(
        (m) => m.recordId == comment.id && m.action == DbConstants.outboxActionDelete,
      );
      expect(deleteMutation, isNotNull);
    });
  });
}
