import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/attachment_repository_impl.dart';

void main() {
  group('AttachmentRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late AttachmentRepositoryImpl repository;
    late String testEventId;

    setUp(() async {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_attachments.db');
      database = AppDatabase(connection);
      repository = AttachmentRepositoryImpl(database: database);

      testEventId = UuidUtils.generate();
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: testEventId,
          userId: 'u1',
          title: '附檔測試活動',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('addAttachment persists metadata, computes thumbnail path, and queues Outbox record', () async {
      final attachment = await repository.addAttachment(
        eventId: testEventId,
        userId: 'u1',
        fileName: 'meeting_notes.jpg',
        fileUrl: repository.getLocalFilePath(testEventId, 'att_1', 'jpg'),
        fileType: 'image/jpeg',
        fileSize: 1024 * 512, // 512 KB
      );

      expect(attachment.fileName, equals('meeting_notes.jpg'));
      expect(attachment.isImage, isTrue);
      expect(attachment.formattedSize, equals('512.0 KB'));
      expect(attachment.thumbnailPath, contains('thumbnails/thumb_${attachment.id}.jpg'));

      final list = await repository.getAttachments(testEventId);
      expect(list.length, equals(1));
      expect(list.first.id, equals(attachment.id));

      final outbox = await database.outboxDao.getPendingMutations();
      final mutation = outbox.firstWhere(
        (m) => m.recordId == attachment.id && m.targetTable == DbConstants.tableEventAttachments,
      );
      expect(mutation.action, equals(DbConstants.outboxActionInsert));
      expect(mutation.payloadJson, contains('meeting_notes.jpg'));
    });

    test('watchAttachments filters strictly by eventId', () async {
      final otherEventId = UuidUtils.generate();
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: otherEventId,
          userId: 'u1',
          title: '另一個行程',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.addAttachment(
        eventId: testEventId,
        userId: 'u1',
        fileName: 'photo_for_event1.png',
        fileUrl: 'path1',
        fileType: 'image/png',
        fileSize: 1024,
      );

      await repository.addAttachment(
        eventId: otherEventId,
        userId: 'u1',
        fileName: 'photo_for_event2.png',
        fileUrl: 'path2',
        fileType: 'image/png',
        fileSize: 2048,
      );

      final event1Attachments = await repository.watchAttachments(testEventId).first;
      expect(event1Attachments.length, equals(1));
      expect(event1Attachments.first.fileName, equals('photo_for_event1.png'));

      final event2Attachments = await repository.watchAttachments(otherEventId).first;
      expect(event2Attachments.length, equals(1));
      expect(event2Attachments.first.fileName, equals('photo_for_event2.png'));
    });

    test('deleteAttachment removes record and enqueues DELETE mutation', () async {
      final attachment = await repository.addAttachment(
        eventId: testEventId,
        userId: 'u1',
        fileName: 'temp.jpg',
        fileUrl: 'path_temp',
        fileType: 'image/jpeg',
        fileSize: 100,
      );

      await repository.deleteAttachment(attachmentId: attachment.id, userId: 'u1');

      final remaining = await repository.getAttachments(testEventId);
      expect(remaining, isEmpty);

      final outbox = await database.outboxDao.getPendingMutations();
      final deleteMutation = outbox.firstWhere(
        (m) => m.recordId == attachment.id && m.action == DbConstants.outboxActionDelete,
      );
      expect(deleteMutation, isNotNull);
    });
  });
}
