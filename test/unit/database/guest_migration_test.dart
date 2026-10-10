import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/migrations/guest_migration_executor.dart';
import 'package:smart_calendar_hub/core/database/migrations/migration_models.dart';
import 'package:smart_calendar_hub/core/errors/failures.dart';

void main() {
  group('Features #10 & #11: Transactional Guest Data Migration Tests', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase guestDb;
    late AppDatabase userDb;
    late GuestMigrationExecutor executor;

    setUp(() {
      factory = InMemoryDatabaseConnectionFactory();
      guestDb = AppDatabase(factory.createConnection('guest.db'));
      userDb = AppDatabase(factory.createConnection('user_test.db'));
      executor = GuestMigrationExecutor();
    });

    tearDown(() async {
      await guestDb.close();
      await userDb.close();
    });

    test('Brand-new account auto-migration imports all entities and enqueues outbox', () async {
      final now = DateTime.now();

      // 1. Seed guestDb
      // Spaces
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-default',
          userId: 'guest',
          name: '個人',
          type: 'personal',
          color: 0xFF6366F1,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-work',
          userId: 'guest',
          name: '工作',
          type: 'project',
          color: 0xFF06B6D4,
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Events
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-1',
          userId: 'guest',
          title: '訪客晨會',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-2',
          userId: 'guest',
          title: '訪客報告',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-3',
          userId: 'guest',
          title: '跨空間事件',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Space Links
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'ev-1_sp-default',
              eventId: 'ev-1',
              spaceId: 'sp-default',
              createdAt: now,
            ),
          );
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'ev-2_sp-work',
              eventId: 'ev-2',
              spaceId: 'sp-work',
              createdAt: now,
            ),
          );
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'ev-3_sp-default',
              eventId: 'ev-3',
              spaceId: 'sp-default',
              createdAt: now,
            ),
          );
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'ev-3_sp-work',
              eventId: 'ev-3',
              spaceId: 'sp-work',
              createdAt: now,
            ),
          );

      // Comments
      await guestDb.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'cm-1',
          eventId: 'ev-1',
          userId: 'guest',
          authorName: 'Guest',
          content: '準備簡報',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'cm-2',
          eventId: 'ev-2',
          userId: 'guest',
          authorName: 'Guest',
          content: '資料複查',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Attachments
      await guestDb.into(guestDb.eventAttachments).insert(
            EventAttachmentsCompanion.insert(
              id: 'att-1',
              eventId: 'ev-1',
              userId: 'guest',
              fileName: 'slides.pdf',
              fileUrl: 'file:///slides.pdf',
              fileType: 'application/pdf',
              fileSize: 1024,
              createdAt: now,
            ),
          );

      // Checklists
      await guestDb.checklistDao.insertChecklist(
        EventChecklistsCompanion.insert(
          id: 'ck-1',
          eventId: 'ev-1',
          title: '帶筆電',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.checklistDao.insertChecklist(
        EventChecklistsCompanion.insert(
          id: 'ck-2',
          eventId: 'ev-1',
          title: '帶投影線',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Keep Items
      await guestDb.keepItemDao.insertKeepItem(
        KeepItemsCompanion.insert(
          id: 'kp-1',
          userId: 'guest',
          title: '靈感草稿 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.keepItemDao.insertKeepItem(
        KeepItemsCompanion.insert(
          id: 'kp-2',
          userId: 'guest',
          title: '靈感草稿 2',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Pomodoro
      await guestDb.into(guestDb.pomodoroSessions).insert(
            PomodoroSessionsCompanion.insert(
              id: 'pomo-1',
              eventId: const Value('ev-1'),
              userId: 'guest',
              durationMinutes: 25,
              startedAt: now,
            ),
          );

      // 2. Execute migration
      const targetUserId = 'target-user-uid-888';
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.autoMigrate,
      );

      expect(result.success, isTrue);
      expect(result.spacesMigrated, equals(2));
      expect(result.eventsMigrated, equals(3));
      expect(result.linksMigrated, equals(4));
      expect(result.commentsMigrated, equals(2));
      expect(result.attachmentsMigrated, equals(1));
      expect(result.checklistsMigrated, equals(2));
      expect(result.keepItemsMigrated, equals(2));
      expect(result.pomodoroSessionsMigrated, equals(1));

      // 3. Verify userDb
      final uSpaces = await userDb.spaceDao.watchAllSpaces().first;
      expect(uSpaces.length, equals(2));
      expect(uSpaces.every((s) => s.userId == targetUserId), isTrue);

      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(3));
      expect(uEvents.every((e) => e.userId == targetUserId), isTrue);

      final uKeep = await userDb.keepItemDao.watchAllKeepItems().first;
      expect(uKeep.length, equals(2));
      expect(uKeep.every((k) => k.userId == targetUserId), isTrue);

      // Verify syncOutbox
      final pendingOutbox = await userDb.outboxDao.getPendingMutations(limit: 100);
      expect(pendingOutbox.length, equals(17)); // 2 spaces + 3 events + 4 links + 2 comments + 1 attachment + 2 checklists + 2 keep + 1 pomo = 17
      expect(pendingOutbox.every((o) => o.action == 'INSERT'), isTrue);

      // 4. Verify guestDb is completely purged
      final gSpacesAfter = await guestDb.spaceDao.watchAllSpaces().first;
      expect(gSpacesAfter.isEmpty, isTrue);

      final gEventsAfter = await guestDb.eventDao.watchAllEvents().first;
      expect(gEventsAfter.isEmpty, isTrue);

      final gKeepAfter = await guestDb.keepItemDao.watchAllKeepItems().first;
      expect(gKeepAfter.isEmpty, isTrue);
    });

    test('Merge Local strategy remaps guest default space to existing user default space', () async {
      final now = DateTime.now();
      const targetUserId = 'existing-user-123';

      // 1. Existing user has a default personal space in userDb
      await userDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'user-default-space-id',
          userId: targetUserId,
          name: '會員個人空間',
          type: 'personal',
          color: 0xFF6366F1,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Existing user event
      await userDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'user-existing-ev-1',
          userId: targetUserId,
          title: '原有雲端會議',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Guest has a guest default space and an event linked to it
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'guest-default-space-id',
          userId: 'guest',
          name: '訪客預設',
          type: 'personal',
          color: 0xFF123456,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'guest-draft-ev-1',
          userId: 'guest',
          title: '訪客新起草行程',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'guest-link-1',
              eventId: 'guest-draft-ev-1',
              spaceId: 'guest-default-space-id',
              createdAt: now,
            ),
          );

      // 3. Execute Merge Local migration
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.mergeLocal,
      );

      expect(result.success, isTrue);

      // Verify userDb spaces: should NOT have duplicated guest default space!
      final uSpaces = await userDb.spaceDao.watchAllSpaces().first;
      expect(uSpaces.length, equals(1));
      expect(uSpaces.first.id, equals('user-default-space-id'));

      // Total events should be 2
      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(2));

      // The link for 'guest-draft-ev-1' must be remapped to 'user-default-space-id'
      final links = await userDb.select(userDb.eventSpaceLinks).get();
      final migratedLink = links.firstWhere((l) => l.eventId == 'guest-draft-ev-1');
      expect(migratedLink.spaceId, equals('user-default-space-id'));

      // guestDb is purged
      final gEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(gEvents.isEmpty, isTrue);
    });

    test('Discard Local strategy purges guest data without importing to userDb', () async {
      final now = DateTime.now();
      const targetUserId = 'existing-user-discard';

      // userDb has 1 event
      await userDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'existing-event',
          userId: targetUserId,
          title: '既有行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // guestDb has 2 events
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'guest-trash-1',
          userId: 'guest',
          title: '不需要的本機草稿 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'guest-trash-2',
          userId: 'guest',
          title: '不需要的本機草稿 2',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Execute discardLocal
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.discardLocal,
      );

      expect(result.success, isTrue);
      expect(result.mode, equals(MigrationMode.discardLocal));

      // userDb retains only the 1 existing event
      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(1));
      expect(uEvents.first.id, equals('existing-event'));

      // guestDb is purged
      final gEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(gEvents.isEmpty, isTrue);
    });

    test('Atomic Rollback guarantee: guestDb untouched if userDb transaction fails', () async {
      final now = DateTime.now();

      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'important-guest-ev',
          userId: 'guest',
          title: '重要訪客備忘錄',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Ensure userDb is opened first, then closed to guarantee subsequent queries fail
      await userDb.customStatement('SELECT 1;');
      await userDb.close();

      expect(
        () async => await executor.migrate(
          guestDb: guestDb,
          userDb: userDb,
          userId: 'some-user',
          mode: MigrationMode.autoMigrate,
        ),
        throwsA(isA<DatabaseFailure>()),
      );

      // Verify guestDb was NOT purged because migration failed
      final remainingGuestEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(remainingGuestEvents.length, equals(1));
      expect(remainingGuestEvents.first.id, equals('important-guest-ev'));
    });
  });
}
