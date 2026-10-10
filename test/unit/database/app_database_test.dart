import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';

void main() {
  late InMemoryDatabaseConnectionFactory connectionFactory;
  late AppDatabase database;

  setUp(() {
    connectionFactory = InMemoryDatabaseConnectionFactory();
    final connection = connectionFactory.createConnection('test.db');
    database = AppDatabase(connection);
  });

  tearDown(() async {
    await database.close();
  });

  group('AppDatabase schema & DAO operations', () {
    test('SpaceDao inserts and retrieves calendar spaces', () async {
      final now = DateTime.now();
      await database.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'space-1',
          userId: 'guest',
          name: '個人',
          type: 'personal',
          color: 0xFF6366F1,
          createdAt: now,
          updatedAt: now,
          isDefault: const Value(true),
        ),
      );

      final spaces = await database.spaceDao.watchAllSpaces().first;
      expect(spaces.length, equals(1));
      expect(spaces.first.name, equals('個人'));
      expect(spaces.first.isDefault, isTrue);

      final defaultSpace = await database.spaceDao.getDefaultSpace();
      expect(defaultSpace?.id, equals('space-1'));
    });

    test('EventDao inserts, updates, and soft-deletes events', () async {
      final now = DateTime.now();
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'event-1',
          userId: 'guest',
          title: '重要會議',
          startTime: Value(now),
          endTime: Value(now.add(const Duration(hours: 1))),
          isAnchored: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      var event = await database.eventDao.getEventById('event-1');
      expect(event, isNotNull);
      expect(event!.title, equals('重要會議'));
      expect(event.isAnchored, isTrue);

      // Soft delete
      await database.eventDao.softDeleteEvent('event-1');
      final activeEvents = await database.eventDao.watchAllEvents().first;
      expect(activeEvents.isEmpty, isTrue);
    });

    test('EventSpaceLinkDao handles Linked Mirroring across spaces', () async {
      final now = DateTime.now();
      // Insert space
      await database.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'space-work',
          userId: 'guest',
          name: '工作',
          type: 'project',
          color: 0xFF06B6D4,
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Insert event
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'event-shared',
          userId: 'guest',
          title: '跨部門協作',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Link to space
      await database.eventSpaceLinkDao.linkEventToSpaces('event-shared', ['space-work']);

      final spacesForEvent = await database.eventSpaceLinkDao.getSpaceIdsForEvent('event-shared');
      expect(spacesForEvent, contains('space-work'));

      final eventsInSpace = await database.eventSpaceLinkDao.watchEventsForSpace('space-work').first;
      expect(eventsInSpace.length, equals(1));
      expect(eventsInSpace.first.id, equals('event-shared'));
    });

    test('Foreign key cascade deletes remove child records', () async {
      final now = DateTime.now();
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'event-parent',
          userId: 'guest',
          title: '母行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.checklistDao.insertItem(
        EventChecklistsCompanion.insert(
          id: 'check-1',
          eventId: 'event-parent',
          title: '準備簡報',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'comm-1',
          eventId: 'event-parent',
          userId: 'guest',
          authorName: 'Guest User',
          content: '資料已寄出',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final checklistBefore = await database.checklistDao.watchChecklistsForEvent('event-parent').first;
      expect(checklistBefore.length, equals(1));

      // Hard delete parent event
      await database.eventDao.hardDeleteEvent('event-parent');

      final checklistAfter = await database.checklistDao.watchChecklistsForEvent('event-parent').first;
      expect(checklistAfter.isEmpty, isTrue);

      final commentsAfter = await database.commentDao.watchCommentsForEvent('event-parent').first;
      expect(commentsAfter.isEmpty, isTrue);
    });

    test('OutboxDao enqueues and updates mutation status', () async {
      await database.outboxDao.enqueueMutation(
        id: 'outbox-1',
        tableName: 'calendar_events',
        recordId: 'event-101',
        action: 'INSERT',
        payloadJson: '{"title":"測試"}',
      );

      final pending = await database.outboxDao.getPendingMutations();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('outbox-1'));
      expect(pending.first.status, equals('pending'));

      await database.outboxDao.markStatus('outbox-1', 'synced');
      final pendingAfter = await database.outboxDao.getPendingMutations();
      expect(pendingAfter.isEmpty, isTrue);
    });

    test('KeepItemDao and UserDeviceDao CRUD operations', () async {
      final now = DateTime.now();
      // Keep Item
      await database.keepItemDao.insertItem(
        KeepItemsCompanion.insert(
          id: 'keep-1',
          userId: 'guest',
          title: '購買牛奶',
          createdAt: now,
          updatedAt: now,
        ),
      );
      var activeKeep = await database.keepItemDao.watchActiveItems().first;
      expect(activeKeep.length, equals(1));

      await database.keepItemDao.archiveItem('keep-1');
      activeKeep = await database.keepItemDao.watchActiveItems().first;
      expect(activeKeep.isEmpty, isTrue);

      // User Device
      await database.userDeviceDao.upsertDevice(
        UserDevicesCompanion.insert(
          id: 'dev-1',
          userId: 'guest',
          deviceName: 'Windows PC',
          platform: 'windows',
          deviceToken: 'token-abc',
          lastActiveAt: now,
          createdAt: now,
        ),
      );
      final devices = await database.userDeviceDao.watchDevices().first;
      expect(devices.length, equals(1));
      expect(devices.first.deviceName, equals('Windows PC'));
    });
  });
}
