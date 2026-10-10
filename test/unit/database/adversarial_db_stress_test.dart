import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/connection/native_database_connection_factory.dart';

void main() {
  group('Adversarial Stress Test: Dynamic Database Connection Switching & Isolation', () {
    test('resolveDatabaseName edge cases & security isolation', () {
      // Null, empty, or whitespace-only strings must resolve to guest.db
      expect(resolveDatabaseName(null), equals('guest.db'));
      expect(resolveDatabaseName(''), equals('guest.db'));
      expect(resolveDatabaseName('   '), equals('guest.db'));
      expect(resolveDatabaseName('\t\n'), equals('guest.db'));

      // Whitespace trimming produces identical database names
      expect(resolveDatabaseName('  user-123  '), equals(resolveDatabaseName('user-123')));

      // Path traversal attacks are neutralized by SHA-256
      final traversalAttempt1 = resolveDatabaseName('../../etc/passwd');
      expect(traversalAttempt1, startsWith('user_'));
      expect(traversalAttempt1, endsWith('.db'));
      expect(traversalAttempt1.contains('/'), isFalse);
      expect(traversalAttempt1.contains('..'), isFalse);

      final traversalAttempt2 = resolveDatabaseName(r'..\..\windows\system32\cmd.exe');
      expect(traversalAttempt2, startsWith('user_'));
      expect(traversalAttempt2, endsWith('.db'));
      expect(traversalAttempt2.contains(r'\'), isFalse);

      // Extreme unicode and emoji user IDs
      final unicodeName = resolveDatabaseName('👨‍💻_🚀_ユーザー_100%');
      expect(unicodeName, startsWith('user_'));
      expect(unicodeName, endsWith('.db'));
      expect(unicodeName.length, equals(5 + 64 + 3)); // 'user_' + 64 hex + '.db'

      // Large user ID (10,000 characters)
      final largeUid = 'x' * 10000;
      final largeName = resolveDatabaseName(largeUid);
      expect(largeName.length, equals(5 + 64 + 3));

      // Deterministic and distinct
      final name1 = resolveDatabaseName('user-alpha');
      final name2 = resolveDatabaseName('user-beta');
      expect(name1, isNot(equals(name2)));
      expect(name1, equals(resolveDatabaseName('user-alpha')));
    });

    test('Strict multi-tenant physical segregation between Guest, User Alpha, and User Beta', () async {
      final factory = InMemoryDatabaseConnectionFactory();
      final now = DateTime.now();

      final guestDbName = resolveDatabaseName(null);
      final alphaDbName = resolveDatabaseName('user-alpha-uuid');
      final betaDbName = resolveDatabaseName('user-beta-uuid');

      final guestDb = AppDatabase(factory.createConnection(guestDbName));
      final alphaDb = AppDatabase(factory.createConnection(alphaDbName));
      final betaDb = AppDatabase(factory.createConnection(betaDbName));

      // 1. Populate Guest Database
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-guest',
          userId: 'guest',
          name: '訪客空間',
          type: 'personal',
          color: 0xFF111111,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-guest',
          userId: 'guest',
          title: '訪客行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Populate Alpha Database
      await alphaDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-alpha',
          userId: 'user-alpha-uuid',
          name: 'Alpha 專屬空間',
          type: 'personal',
          color: 0xFF222222,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await alphaDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-alpha',
          userId: 'user-alpha-uuid',
          title: 'Alpha 專屬機密行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Verify Beta database is 100% empty
      final betaSpaces = await betaDb.spaceDao.watchAllSpaces().first;
      final betaEvents = await betaDb.eventDao.watchAllEvents().first;
      expect(betaSpaces.isEmpty, isTrue, reason: 'Beta must not see any spaces');
      expect(betaEvents.isEmpty, isTrue, reason: 'Beta must not see any events');

      // 4. Verify Alpha does not see Guest records
      final alphaSpaces = await alphaDb.spaceDao.watchAllSpaces().first;
      final alphaEvents = await alphaDb.eventDao.watchAllEvents().first;
      expect(alphaSpaces.map((s) => s.id), contains('sp-alpha'));
      expect(alphaSpaces.map((s) => s.id), isNot(contains('sp-guest')));
      expect(alphaEvents.map((e) => e.id), contains('ev-alpha'));
      expect(alphaEvents.map((e) => e.id), isNot(contains('ev-guest')));

      // 5. Verify Guest does not see Alpha records
      final guestSpaces = await guestDb.spaceDao.watchAllSpaces().first;
      final guestEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(guestSpaces.map((s) => s.id), contains('sp-guest'));
      expect(guestSpaces.map((s) => s.id), isNot(contains('sp-alpha')));
      expect(guestEvents.map((e) => e.id), contains('ev-guest'));
      expect(guestEvents.map((e) => e.id), isNot(contains('ev-alpha')));

      // 6. Delete Alpha database, ensure Guest is completely intact
      await alphaDb.close();
      await factory.deleteDatabase(alphaDbName);

      final guestSpacesAfter = await guestDb.spaceDao.watchAllSpaces().first;
      expect(guestSpacesAfter.length, equals(1));
      expect(guestSpacesAfter.first.id, equals('sp-guest'));

      await guestDb.close();
      await betaDb.close();
    });
  });

  group('Adversarial Stress Test: Logout Connection Lifecycle & Query Severing', () {
    test('Riverpod lifecycle severs connection on logout and invalidates queries on stale instance', () async {
      final factory = InMemoryDatabaseConnectionFactory();
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);

      // Start as Guest
      final initialGuestDb = container.read(appDatabaseProvider);
      final now = DateTime.now();
      await initialGuestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-guest-init',
          userId: 'guest',
          name: '訪客初期空間',
          type: 'personal',
          color: 0xFF123456,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Log in as user
      container.read(currentAuthForDbProvider.notifier).state =
          const AuthenticatedDbAuthState('user-gamma');
      final userDb = container.read(appDatabaseProvider);
      expect(identical(initialGuestDb, userDb), isFalse);
      await userDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-user-gamma',
          userId: 'user-gamma',
          name: '用戶空間',
          type: 'personal',
          color: 0xFF654321,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Old initialGuestDb should have been closed by ref.onDispose
      expect(
        () async => await initialGuestDb.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Executing queries on disposed database connection must fail',
      );

      // Log out back to guest
      container.read(currentAuthForDbProvider.notifier).state =
          const GuestDbAuthState();
      final afterLogoutDb = container.read(appDatabaseProvider);
      expect(identical(userDb, afterLogoutDb), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // User database should now be closed
      expect(
        () async => await userDb.eventDao.watchAllEvents().first,
        throwsA(anything),
        reason: 'User database connection must be closed upon logout',
      );

      // New guest database should execute queries without errors
      final freshGuestSpaces = await afterLogoutDb.spaceDao.watchAllSpaces().first;
      expect(freshGuestSpaces, isNotNull);
    });

    test('Manual database.close() immediately severs SQLite handle', () async {
      final factory = InMemoryDatabaseConnectionFactory();
      final db = AppDatabase(factory.createConnection('close_test.db'));

      final now = DateTime.now();
      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-close-test',
          userId: 'guest',
          name: '測試空間',
          type: 'personal',
          color: 0xFF444444,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Close database
      await db.close();

      // Subsequent read query must fail
      expect(
        () async => await db.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Read query on closed database must throw',
      );

      // Subsequent write query must fail
      expect(
        () async => await db.spaceDao.insertSpace(
          CalendarSpacesCompanion.insert(
            id: 'sp-post-close',
            userId: 'guest',
            name: '關閉後插入',
            type: 'personal',
            color: 0xFF555555,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Insert on closed database must throw',
      );
    });
  });

  group('Adversarial Stress Test: Foreign Key Constraint Violations & Cascade Deletes', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase db;

    setUp(() {
      factory = InMemoryDatabaseConnectionFactory();
      db = AppDatabase(factory.createConnection('fk_stress.db'));
    });

    tearDown(() async {
      await db.close();
    });

    test('Violating Foreign Keys on EventSpaceLinks throws constraint exception', () async {
      final now = DateTime.now();
      // Insert valid space
      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-valid',
          userId: 'guest',
          name: '有效空間',
          type: 'personal',
          color: 0xFF000000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 1. Linking non-existent eventId must fail
      expect(
        () async => await db.into(db.eventSpaceLinks).insert(
          EventSpaceLinksCompanion.insert(
            id: 'link-invalid-event',
            eventId: 'non-existent-event-id',
            spaceId: 'sp-valid',
            createdAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Foreign key constraint calendar_events(id) must be enforced',
      );

      // Insert valid event
      await db.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-valid',
          userId: 'guest',
          title: '有效行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Linking non-existent spaceId must fail
      expect(
        () async => await db.into(db.eventSpaceLinks).insert(
          EventSpaceLinksCompanion.insert(
            id: 'link-invalid-space',
            eventId: 'ev-valid',
            spaceId: 'non-existent-space-id',
            createdAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Foreign key constraint calendar_spaces(id) must be enforced',
      );

      // 3. Valid link succeeds
      await db.into(db.eventSpaceLinks).insert(
        EventSpaceLinksCompanion.insert(
          id: 'link-valid-1',
          eventId: 'ev-valid',
          spaceId: 'sp-valid',
          createdAt: now,
        ),
      );

      // 4. Duplicate (eventId, spaceId) violates unique constraint
      expect(
        () async => await db.into(db.eventSpaceLinks).insert(
          EventSpaceLinksCompanion.insert(
            id: 'link-valid-2',
            eventId: 'ev-valid',
            spaceId: 'sp-valid',
            createdAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Unique constraint on {eventId, spaceId} must be enforced',
      );
    });

    test('Violating Foreign Keys on Comments, Attachments, Checklists throws', () async {
      final now = DateTime.now();

      // Comment on non-existent event
      expect(
        () async => await db.commentDao.insertComment(
          EventCommentsCompanion.insert(
            id: 'comm-orphan',
            eventId: 'ghost-event-id',
            userId: 'guest',
            authorName: 'Ghost',
            content: 'Ghost comment',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Comment on non-existent event must violate foreign key',
      );

      // Attachment on non-existent event
      expect(
        () async => await db.into(db.eventAttachments).insert(
          EventAttachmentsCompanion.insert(
            id: 'att-orphan',
            eventId: 'ghost-event-id',
            userId: 'guest',
            fileName: 'doc.pdf',
            fileUrl: '/path/doc.pdf',
            fileType: 'application/pdf',
            fileSize: 1024,
            createdAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Attachment on non-existent event must violate foreign key',
      );

      // Checklist item on non-existent event
      expect(
        () async => await db.checklistDao.insertItem(
          EventChecklistsCompanion.insert(
            id: 'chk-orphan',
            eventId: 'ghost-event-id',
            title: 'Orphan checklist',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Checklist item on non-existent event must violate foreign key',
      );
    });

    test('Full cascade delete tree when CalendarEvent is hard-deleted', () async {
      final now = DateTime.now();

      // Setup 2 spaces
      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-1',
          userId: 'guest',
          name: '空間一',
          type: 'personal',
          color: 0xFF111111,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-2',
          userId: 'guest',
          name: '空間二',
          type: 'family',
          color: 0xFF222222,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Setup Parent Event
      await db.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-root',
          userId: 'guest',
          title: '核心樹行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Link to both spaces
      await db.eventSpaceLinkDao.linkEventToSpaces('ev-root', ['sp-1', 'sp-2']);

      // Add 2 comments
      await db.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'comm-1',
          eventId: 'ev-root',
          userId: 'guest',
          authorName: 'User A',
          content: '第一則留言',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'comm-2',
          eventId: 'ev-root',
          userId: 'guest',
          authorName: 'User B',
          content: '第二則留言',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Add 2 attachments
      await db.into(db.eventAttachments).insert(
        EventAttachmentsCompanion.insert(
          id: 'att-1',
          eventId: 'ev-root',
          userId: 'guest',
          fileName: 'agenda.pdf',
          fileUrl: '/docs/agenda.pdf',
          fileType: 'pdf',
          fileSize: 2048,
          createdAt: now,
        ),
      );
      await db.into(db.eventAttachments).insert(
        EventAttachmentsCompanion.insert(
          id: 'att-2',
          eventId: 'ev-root',
          userId: 'guest',
          fileName: 'photo.jpg',
          fileUrl: '/images/photo.jpg',
          fileType: 'jpeg',
          fileSize: 4096,
          createdAt: now,
        ),
      );

      // Add 2 checklists
      await db.checklistDao.insertItem(
        EventChecklistsCompanion.insert(
          id: 'chk-1',
          eventId: 'ev-root',
          title: '檢查清單一',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.checklistDao.insertItem(
        EventChecklistsCompanion.insert(
          id: 'chk-2',
          eventId: 'ev-root',
          title: '檢查清單二',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Add Pomodoro session (ON DELETE SET NULL)
      await db.into(db.pomodoroSessions).insert(
        PomodoroSessionsCompanion.insert(
          id: 'pomo-1',
          eventId: const Value('ev-root'),
          userId: 'guest',
          durationMinutes: 25,
          startedAt: now,
        ),
      );

      // Pre-deletion checks
      final linksBefore = await (db.select(db.eventSpaceLinks)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(linksBefore.length, equals(2));
      final commentsBefore = await (db.select(db.eventComments)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(commentsBefore.length, equals(2));
      final attachmentsBefore = await (db.select(db.eventAttachments)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(attachmentsBefore.length, equals(2));
      final checklistsBefore = await (db.select(db.eventChecklists)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(checklistsBefore.length, equals(2));
      final pomosBefore = await (db.select(db.pomodoroSessions)..where((t) => t.id.equals('pomo-1'))).get();
      expect(pomosBefore.first.eventId, equals('ev-root'));

      // HARD DELETE PARENT EVENT
      final deletedCount = await db.eventDao.hardDeleteEvent('ev-root');
      expect(deletedCount, equals(1));

      // Post-deletion verification: All cascading children must be gone
      final linksAfter = await (db.select(db.eventSpaceLinks)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(linksAfter.isEmpty, isTrue, reason: 'EventSpaceLinks must be cascade deleted');

      final commentsAfter = await (db.select(db.eventComments)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(commentsAfter.isEmpty, isTrue, reason: 'EventComments must be cascade deleted');

      final attachmentsAfter = await (db.select(db.eventAttachments)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(attachmentsAfter.isEmpty, isTrue, reason: 'EventAttachments must be cascade deleted');

      final checklistsAfter = await (db.select(db.eventChecklists)..where((t) => t.eventId.equals('ev-root'))).get();
      expect(checklistsAfter.isEmpty, isTrue, reason: 'EventChecklists must be cascade deleted');

      // Spaces must remain completely untouched
      final spacesAfter = await db.spaceDao.watchAllSpaces().first;
      expect(spacesAfter.length, equals(2));

      // Pomodoro session must still exist, but eventId must be NULL (ON DELETE SET NULL)
      final pomosAfter = await (db.select(db.pomodoroSessions)..where((t) => t.id.equals('pomo-1'))).get();
      expect(pomosAfter.length, equals(1));
      expect(pomosAfter.first.eventId, isNull, reason: 'PomodoroSession eventId must be set to NULL on event deletion');
    });

    test('Deleting CalendarSpace cascades links without deleting CalendarEvents', () async {
      final now = DateTime.now();

      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-victim',
          userId: 'guest',
          name: '待刪除空間',
          type: 'personal',
          color: 0xFF333333,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-survivor',
          userId: 'guest',
          title: '存活行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.eventSpaceLinkDao.linkEventToSpaces('ev-survivor', ['sp-victim']);

      final linksBefore = await db.eventSpaceLinkDao.getSpaceIdsForEvent('ev-survivor');
      expect(linksBefore, contains('sp-victim'));

      // Hard delete space
      await (db.delete(db.calendarSpaces)..where((t) => t.id.equals('sp-victim'))).go();

      // Links must be cascade-deleted
      final linksAfter = await db.eventSpaceLinkDao.getSpaceIdsForEvent('ev-survivor');
      expect(linksAfter.isEmpty, isTrue, reason: 'Space links must be cascade deleted when space is deleted');

      // Event must still exist!
      final event = await db.eventDao.getEventById('ev-survivor');
      expect(event, isNotNull, reason: 'Event must survive space deletion');
      expect(event!.title, equals('存活行程'));
    });
  });

  group('Adversarial Stress Test: Concurrency & Transaction Rollbacks', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase db;

    setUp(() {
      factory = InMemoryDatabaseConnectionFactory();
      db = AppDatabase(factory.createConnection('tx_concurrency.db'));
    });

    tearDown(() async {
      await db.close();
    });

    test('Transaction rollbacks on SQLite constraint violation leaving DB consistent', () async {
      final now = DateTime.now();

      try {
        await db.transaction(() async {
          // 1. Insert space
          await db.spaceDao.insertSpace(
            CalendarSpacesCompanion.insert(
              id: 'sp-tx-fail',
              userId: 'guest',
              name: '交易空間',
              type: 'personal',
              color: 0xFF123456,
              createdAt: now,
              updatedAt: now,
            ),
          );

          // 2. Insert event
          await db.eventDao.insertEvent(
            CalendarEventsCompanion.insert(
              id: 'ev-tx-fail',
              userId: 'guest',
              title: '交易行程',
              createdAt: now,
              updatedAt: now,
            ),
          );

          // 3. Deliberately trigger foreign key constraint violation
          await db.into(db.eventComments).insert(
            EventCommentsCompanion.insert(
              id: 'comm-tx-fail',
              eventId: 'non-existent-event-triggering-failure',
              userId: 'guest',
              authorName: 'Failbot',
              content: 'Will blow up',
              createdAt: now,
              updatedAt: now,
            ),
          );
        });
        fail('Transaction should have thrown SQLite exception');
      } catch (e) {
        expect(e, isNotNull);
      }

      // Assert rollback: neither space nor event should exist!
      final space = await (db.select(db.calendarSpaces)..where((t) => t.id.equals('sp-tx-fail'))).getSingleOrNull();
      expect(space, isNull, reason: 'Space must be rolled back on transaction error');

      final event = await db.eventDao.getEventById('ev-tx-fail');
      expect(event, isNull, reason: 'Event must be rolled back on transaction error');

      // Verify database is still operational after rollback
      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-tx-recovered',
          userId: 'guest',
          name: '復原後空間',
          type: 'personal',
          color: 0xFF654321,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final recoveredSpace = await (db.select(db.calendarSpaces)..where((t) => t.id.equals('sp-tx-recovered'))).getSingleOrNull();
      expect(recoveredSpace, isNotNull);
    });

    test('Transaction rollbacks on application error', () async {
      final now = DateTime.now();

      try {
        await db.transaction(() async {
          await db.eventDao.insertEvent(
            CalendarEventsCompanion.insert(
              id: 'ev-app-rollback',
              userId: 'guest',
              title: '手動中止行程',
              createdAt: now,
              updatedAt: now,
            ),
          );
          throw StateError('Simulated business logic crash during sync');
        });
      } catch (e) {
        expect(e, isA<StateError>());
      }

      final event = await db.eventDao.getEventById('ev-app-rollback');
      expect(event, isNull, reason: 'Event must be rolled back on application exception');
    });

    test('High-concurrency stress test with 100 interleaved operations', () async {
      final now = DateTime.now();
      const int operationCount = 100;

      // Execute 100 concurrent asynchronous inserts across events, outbox, and keep items
      final futures = <Future>[];
      for (int i = 0; i < operationCount; i++) {
        if (i % 3 == 0) {
          futures.add(
            db.eventDao.insertEvent(
              CalendarEventsCompanion.insert(
                id: 'concurrent-ev-$i',
                userId: 'guest',
                title: '併發行程 $i',
                createdAt: now,
                updatedAt: now,
              ),
            ),
          );
        } else if (i % 3 == 1) {
          futures.add(
            db.outboxDao.enqueueMutation(
              id: 'concurrent-outbox-$i',
              tableName: 'calendar_events',
              recordId: 'rec-$i',
              action: 'INSERT',
              payloadJson: '{"index": $i}',
            ),
          );
        } else {
          futures.add(
            db.keepItemDao.insertItem(
              KeepItemsCompanion.insert(
                id: 'concurrent-keep-$i',
                userId: 'guest',
                title: '併發靈感 $i',
                createdAt: now,
                updatedAt: now,
              ),
            ),
          );
        }
      }

      // Must complete all 100 concurrent operations without database lock errors
      await Future.wait(futures);

      final events = await (db.select(db.calendarEvents)..where((t) => t.id.like('concurrent-ev-%'))).get();
      final outbox = await (db.select(db.syncOutbox)..where((t) => t.id.like('concurrent-outbox-%'))).get();
      final keep = await (db.select(db.keepItems)..where((t) => t.id.like('concurrent-keep-%'))).get();

      final totalInserted = events.length + outbox.length + keep.length;
      expect(totalInserted, equals(operationCount), reason: 'All 100 concurrent writes must succeed');
    });
  });

  group('Adversarial Stress Test: Native File-Backed Database Lifecycle', () {
    test('File-backed database preserves state across closes and deletes cleanly', () async {
      final tempDir = await Directory.systemTemp.createTemp('chronohub_stress_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );

      const guestDbName = 'guest.db';
      final now = DateTime.now();

      // 1. Open guest DB and write records
      var dbConn = nativeFactory.createConnection(guestDbName);
      var db = AppDatabase(dbConn);
      await db.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-persistent',
          userId: 'guest',
          name: '硬碟持久空間',
          type: 'personal',
          color: 0xFF999999,
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Close connection
      await db.close();

      // 2. Verify file exists on disk
      expect(await nativeFactory.databaseExists(guestDbName), isTrue);

      // 3. Re-open same database file
      dbConn = nativeFactory.createConnection(guestDbName);
      db = AppDatabase(dbConn);
      final loadedSpaces = await db.spaceDao.watchAllSpaces().first;
      expect(loadedSpaces.length, equals(1));
      expect(loadedSpaces.first.id, equals('sp-persistent'));
      expect(loadedSpaces.first.name, equals('硬碟持久空間'));
      await db.close();

      // 4. Delete database file & WAL/SHM
      await nativeFactory.deleteDatabase(guestDbName);
      expect(await nativeFactory.databaseExists(guestDbName), isFalse);

      final dbFile = await nativeFactory.getDatabaseFile(guestDbName);
      expect(await dbFile.exists(), isFalse, reason: 'Database file must be deleted from disk');
    });
  });
}
