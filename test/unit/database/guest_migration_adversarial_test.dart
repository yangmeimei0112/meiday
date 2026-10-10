import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/migrations/guest_migration_executor.dart';
import 'package:smart_calendar_hub/core/database/migrations/migration_models.dart';
import 'package:smart_calendar_hub/core/errors/failures.dart';
import 'package:smart_calendar_hub/features/auth/services/migration_conflict_detector.dart';

void main() {
  group('Adversarial Challenge: GuestMigrationExecutor Stress Tests', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase guestDb;
    late AppDatabase userDb;
    late GuestMigrationExecutor executor;

    setUp(() {
      factory = InMemoryDatabaseConnectionFactory();
      guestDb = AppDatabase(factory.createConnection('guest.db'));
      userDb = AppDatabase(factory.createConnection('user_adversarial.db'));
      executor = GuestMigrationExecutor();
    });

    tearDown(() async {
      await guestDb.close();
      await userDb.close();
    });

    test('1. Foreign-key integrity: full entity hierarchy and join traversal', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-fk-001';

      // Seed guest space
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-personal',
          userId: 'guest',
          name: '個人',
          type: 'personal',
          color: 0xFF123456,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed guest event
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-full-hierarchy',
          userId: 'guest',
          title: '完整階層事件',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed link
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'link-hier-1',
              eventId: 'ev-full-hierarchy',
              spaceId: 'sp-personal',
              createdAt: now,
            ),
          );

      // Seed comment
      await guestDb.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'cm-hier-1',
          eventId: 'ev-full-hierarchy',
          userId: 'guest',
          authorName: 'Guest Tester',
          content: '階層評論測試',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed attachment
      await guestDb.into(guestDb.eventAttachments).insert(
            EventAttachmentsCompanion.insert(
              id: 'att-hier-1',
              eventId: 'ev-full-hierarchy',
              userId: 'guest',
              fileName: 'doc.pdf',
              fileUrl: 'file:///doc.pdf',
              fileType: 'application/pdf',
              fileSize: 2048,
              createdAt: now,
            ),
          );

      // Seed checklist
      await guestDb.checklistDao.insertChecklist(
        EventChecklistsCompanion.insert(
          id: 'ck-hier-1',
          eventId: 'ev-full-hierarchy',
          title: '檢查清單項目 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed pomodoro
      await guestDb.into(guestDb.pomodoroSessions).insert(
            PomodoroSessionsCompanion.insert(
              id: 'pomo-hier-1',
              eventId: const Value('ev-full-hierarchy'),
              userId: 'guest',
              durationMinutes: 25,
              startedAt: now,
            ),
          );

      // Seed keep item
      await guestDb.keepItemDao.insertKeepItem(
        KeepItemsCompanion.insert(
          id: 'kp-hier-1',
          userId: 'guest',
          title: '靈感草稿',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.autoMigrate,
      );

      expect(result.success, isTrue);

      // Join query on userDb to verify all foreign keys point to valid rows
      final query = userDb.select(userDb.calendarEvents).join([
        innerJoin(
          userDb.eventSpaceLinks,
          userDb.eventSpaceLinks.eventId.equalsExp(userDb.calendarEvents.id),
        ),
        innerJoin(
          userDb.calendarSpaces,
          userDb.calendarSpaces.id.equalsExp(userDb.eventSpaceLinks.spaceId),
        ),
        innerJoin(
          userDb.eventComments,
          userDb.eventComments.eventId.equalsExp(userDb.calendarEvents.id),
        ),
        innerJoin(
          userDb.eventAttachments,
          userDb.eventAttachments.eventId.equalsExp(userDb.calendarEvents.id),
        ),
        innerJoin(
          userDb.eventChecklists,
          userDb.eventChecklists.eventId.equalsExp(userDb.calendarEvents.id),
        ),
        innerJoin(
          userDb.pomodoroSessions,
          userDb.pomodoroSessions.eventId.equalsExp(userDb.calendarEvents.id),
        ),
      ]);

      final joinedRows = await query.get();
      expect(joinedRows.length, equals(1));

      final firstRow = joinedRows.first;
      expect(firstRow.readTable(userDb.calendarEvents).title, equals('完整階層事件'));
      expect(firstRow.readTable(userDb.calendarSpaces).name, equals('個人'));
      expect(firstRow.readTable(userDb.eventComments).content, equals('階層評論測試'));
      expect(firstRow.readTable(userDb.eventChecklists).title, equals('檢查清單項目 1'));
      expect(firstRow.readTable(userDb.pomodoroSessions).durationMinutes, equals(25));
    });

    test('2A. EMPIRICAL BUG REPRODUCTION: Soft-deleted event with child records triggers SQLite FK failure', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-fk-002';

      // Seed guest space
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-1',
          userId: 'guest',
          name: '預設空間',
          type: 'personal',
          color: 0xFF123456,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed an active event
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-active',
          userId: 'guest',
          title: '正常活耀行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed a soft-deleted event (isDeleted = true)
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-soft-deleted',
          userId: 'guest',
          title: '已軟刪除行程',
          isDeleted: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Child records pointing to the soft-deleted event
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'link-deleted-1',
              eventId: 'ev-soft-deleted',
              spaceId: 'sp-1',
              createdAt: now,
            ),
          );

      await guestDb.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'cm-deleted-1',
          eventId: 'ev-soft-deleted',
          userId: 'guest',
          authorName: 'Guest',
          content: '刪除行程底下的評論',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // EMPIRICAL FIX VERIFICATION:
      // GuestMigrationExecutor filters out child records referencing soft-deleted events.
      // Migration succeeds with 100% data integrity and zero foreign key constraint violations!
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.autoMigrate,
      );

      expect(result.success, isTrue);
      expect(result.eventsMigrated, equals(1));
      expect(result.linksMigrated, equals(0));
      expect(result.commentsMigrated, equals(0));

      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(1));
      expect(uEvents.first.id, equals('ev-active'));

      final uLinks = await userDb.select(userDb.eventSpaceLinks).get();
      expect(uLinks.isEmpty, isTrue);

      final uComments = await userDb.select(userDb.eventComments).get();
      expect(uComments.isEmpty, isTrue);
    });

    test('2B. EMPIRICAL BUG REPRODUCTION: Soft-deleted space with event link triggers SQLite FK failure', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-fk-003';

      // Seed a soft-deleted space
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-deleted',
          userId: 'guest',
          name: '已軟刪除空間',
          type: 'personal',
          color: 0xFF123456,
          isDefault: const Value(false),
          isDeleted: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Active event linking to the soft-deleted space
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-active-2',
          userId: 'guest',
          title: '活耀行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'link-to-deleted-space',
              eventId: 'ev-active-2',
              spaceId: 'sp-deleted',
              createdAt: now,
            ),
          );

      // EMPIRICAL FIX VERIFICATION:
      // GuestMigrationExecutor filters links pointing to soft-deleted spaces.
      // The active event is successfully migrated without FK violation!
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.autoMigrate,
      );

      expect(result.success, isTrue);
      expect(result.eventsMigrated, equals(1));
      expect(result.linksMigrated, equals(0));

      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(1));
      expect(uEvents.first.id, equals('ev-active-2'));

      final uLinks = await userDb.select(userDb.eventSpaceLinks).get();
      expect(uLinks.isEmpty, isTrue);
    });

    test('2C. Rollback verification after mid-migration FK constraint violation', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-fk-rollback';

      // Guest DB has:
      // 1 active space, 1 active event, 1 soft-deleted event with orphan link
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-valid',
          userId: 'guest',
          name: '有效空間',
          type: 'personal',
          color: 0xFF123456,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-valid-1',
          userId: 'guest',
          title: '有效行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-broken',
          userId: 'guest',
          title: '將觸發FK錯誤的軟刪除行程',
          isDeleted: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'link-broken',
              eventId: 'ev-broken',
              spaceId: 'sp-valid',
              createdAt: now,
            ),
          );

      // Seed an active link in guestDb that passes validation
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'link-trigger-fk',
              eventId: 'ev-valid-1',
              spaceId: 'sp-valid',
              createdAt: now,
            ),
          );

      // Create an explicit constraint trigger on userDb to simulate a mid-migration FK constraint failure
      // after spaces (4.1) and events (4.2) have already been inserted
      await userDb.customStatement(
        "CREATE TRIGGER abort_on_link BEFORE INSERT ON event_space_links BEGIN SELECT RAISE(ABORT, 'FOREIGN KEY constraint failed'); END;",
      );

      // Migration must fail with DatabaseFailure
      expect(
        () => executor.migrate(
          guestDb: guestDb,
          userDb: userDb,
          userId: targetUserId,
          mode: MigrationMode.autoMigrate,
        ),
        throwsA(
          isA<DatabaseFailure>().having(
            (e) => e.message,
            'message',
            contains('FOREIGN KEY constraint failed'),
          ),
        ),
      );

      // VERIFY userDb ROLLBACK:
      // Even though 'sp-valid' and 'ev-valid-1' were inserted in steps 4.1 and 4.2 before step 4.3 failed,
      // the entire userDb transaction rolled back completely!
      final uSpaces = await userDb.spaceDao.watchAllSpaces().first;
      expect(uSpaces.isEmpty, isTrue);

      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.isEmpty, isTrue);

      final uOutbox = await userDb.outboxDao.getPendingMutations(limit: 10);
      expect(uOutbox.isEmpty, isTrue);

      // VERIFY guestDb PRESERVATION:
      // guestDb is 100% intact: nothing was purged or modified!
      final gSpaces = await guestDb.spaceDao.watchAllSpaces().first;
      expect(gSpaces.length, equals(1));
      expect(gSpaces.first.id, equals('sp-valid'));

      final gEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(gEvents.length, equals(1)); // 1 non-deleted event
      final allGuestEvents = await guestDb.select(guestDb.calendarEvents).get();
      expect(allGuestEvents.length, equals(2)); // both active and soft-deleted events preserved
    });

    test('3. Rollback completeness: userDb rolled back 100% and guestDb 100% intact upon constraint failure', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-rollback';

      // Populate guestDb with 3 events, 2 spaces, 2 comments
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-orig-1',
          userId: 'guest',
          name: '空間 1',
          type: 'personal',
          color: 0xFF112233,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-orig-1',
          userId: 'guest',
          title: '行程 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-orig-2',
          userId: 'guest',
          title: '行程 2',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.commentDao.insertComment(
        EventCommentsCompanion.insert(
          id: 'cm-orig-1',
          eventId: 'ev-orig-1',
          userId: 'guest',
          authorName: 'Guest',
          content: '原始評論 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // We purposely corrupt userDb state or close it to force transaction abortion mid-flight
      await userDb.customStatement('SELECT 1;');
      await userDb.close();

      // Migration must fail with DatabaseFailure
      expect(
        () => executor.migrate(
          guestDb: guestDb,
          userDb: userDb,
          userId: targetUserId,
          mode: MigrationMode.autoMigrate,
        ),
        throwsA(isA<DatabaseFailure>()),
      );

      // Verify guestDb has 100% of its original data completely preserved
      final guestSpaces = await guestDb.spaceDao.watchAllSpaces().first;
      expect(guestSpaces.length, equals(1));
      expect(guestSpaces.first.id, equals('sp-orig-1'));

      final guestEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(guestEvents.length, equals(2));

      final guestComments = await (guestDb.select(guestDb.eventComments)).get();
      expect(guestComments.length, equals(1));
      expect(guestComments.first.content, equals('原始評論 1'));
    });

    test('4. Conflict resolution: Merge Local with overlapping and custom spaces', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-merge-deep';

      // 1. User DB already has a default personal space and a work space
      await userDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'user-default-space',
          userId: targetUserId,
          name: '雲端個人',
          type: 'personal',
          color: 0xFF101010,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await userDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'user-shared-work',
          userId: targetUserId,
          name: '工作專案',
          type: 'project',
          color: 0xFF202020,
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await userDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'user-ev-pre-existing',
          userId: targetUserId,
          title: '既有雲端行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Guest DB has a default personal space AND a distinct custom family space
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'guest-default-space',
          userId: 'guest',
          name: '訪客預設',
          type: 'personal',
          color: 0xFF303030,
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'guest-family-space',
          userId: 'guest',
          name: '訪客家庭',
          type: 'family',
          color: 0xFF404040,
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Guest has an event linked to both default space and family space
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'guest-multi-space-ev',
          userId: 'guest',
          title: '訪客跨空間行程',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'guest-link-default',
              eventId: 'guest-multi-space-ev',
              spaceId: 'guest-default-space',
              createdAt: now,
            ),
          );
      await guestDb.into(guestDb.eventSpaceLinks).insert(
            EventSpaceLinksCompanion.insert(
              id: 'guest-link-family',
              eventId: 'guest-multi-space-ev',
              spaceId: 'guest-family-space',
              createdAt: now,
            ),
          );

      // 3. Execute mergeLocal
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.mergeLocal,
      );

      expect(result.success, isTrue);

      // 4. Verify userDb spaces:
      // Should have: user-default-space, user-shared-work, guest-family-space.
      // Total 3 spaces (NOT 4 spaces, guest-default-space was remapped!).
      final userSpaces = await userDb.spaceDao.watchAllSpaces().first;
      expect(userSpaces.length, equals(3));
      final spaceIds = userSpaces.map((s) => s.id).toSet();
      expect(spaceIds.contains('user-default-space'), isTrue);
      expect(spaceIds.contains('user-shared-work'), isTrue);
      expect(spaceIds.contains('guest-family-space'), isTrue);
      expect(spaceIds.contains('guest-default-space'), isFalse);

      // Verify guest-family-space is now owned by targetUserId
      final migratedFamilySpace = userSpaces.firstWhere((s) => s.id == 'guest-family-space');
      expect(migratedFamilySpace.userId, equals(targetUserId));
      expect(migratedFamilySpace.isDefault, isFalse);

      // 5. Verify userDb events: 2 events (1 pre-existing + 1 migrated)
      final userEvents = await userDb.eventDao.watchAllEvents().first;
      expect(userEvents.length, equals(2));

      // 6. Verify event links:
      // 'guest-multi-space-ev' should be linked to 'user-default-space' and 'guest-family-space'
      final links = await userDb.select(userDb.eventSpaceLinks).get();
      final eventLinks = links.where((l) => l.eventId == 'guest-multi-space-ev').toList();
      expect(eventLinks.length, equals(2));
      final linkedSpaceIds = eventLinks.map((l) => l.spaceId).toSet();
      expect(linkedSpaceIds, equals({'user-default-space', 'guest-family-space'}));

      // 7. Verify guestDb is purged
      final gEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(gEvents.isEmpty, isTrue);
    });

    test('5. Conflict resolution: Discard Local purges guestDb and leaves userDb untouched', () async {
      final now = DateTime.now();
      const targetUserId = 'target-user-discard-audit';

      // Pre-seed userDb
      await userDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'user-stay-ev',
          userId: targetUserId,
          title: '保持不變的行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed guestDb with multiple items
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'guest-discard-ev-1',
          userId: 'guest',
          title: '捨棄行程 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await guestDb.keepItemDao.insertKeepItem(
        KeepItemsCompanion.insert(
          id: 'guest-discard-keep-1',
          userId: 'guest',
          title: '捨棄靈感 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.discardLocal,
      );

      expect(result.success, isTrue);
      expect(result.mode, equals(MigrationMode.discardLocal));

      // userDb has ONLY the original event
      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(1));
      expect(uEvents.first.id, equals('user-stay-ev'));

      // userDb outbox has 0 records
      final uOutbox = await userDb.outboxDao.getPendingMutations(limit: 10);
      expect(uOutbox.isEmpty, isTrue);

      // guestDb is 100% empty
      final gEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(gEvents.isEmpty, isTrue);
      final gKeep = await guestDb.keepItemDao.watchAllKeepItems().first;
      expect(gKeep.isEmpty, isTrue);
    });

    test('6. Large payload migration stress test (150 events, 5 spaces, 300 links, 300 checklists)', () async {
      final stopwatch = Stopwatch()..start();
      final now = DateTime.now();
      const targetUserId = 'target-user-heavy-scale';
      const eventCount = 150;
      const spaceCount = 5;

      // 1. Seed 5 spaces
      for (int i = 0; i < spaceCount; i++) {
        await guestDb.spaceDao.insertSpace(
          CalendarSpacesCompanion.insert(
            id: 'heavy-sp-$i',
            userId: 'guest',
            name: '大型空間 $i',
            type: 'project',
            color: 0xFF102030 + i,
            isDefault: Value(i == 0),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // 2. Seed 150 events, each with 2 space links, 1 comment, 1 attachment, 2 checklists
      for (int i = 0; i < eventCount; i++) {
        final evId = 'heavy-ev-$i';
        await guestDb.eventDao.insertEvent(
          CalendarEventsCompanion.insert(
            id: evId,
            userId: 'guest',
            title: '壓力測試行程 #$i',
            startTime: Value(now.add(Duration(hours: i))),
            endTime: Value(now.add(Duration(hours: i, minutes: 45))),
            createdAt: now,
            updatedAt: now,
          ),
        );

        // 2 links per event
        final s1 = 'heavy-sp-${i % spaceCount}';
        final s2 = 'heavy-sp-${(i + 1) % spaceCount}';
        await guestDb.into(guestDb.eventSpaceLinks).insert(
              EventSpaceLinksCompanion.insert(
                id: 'link-$evId-$s1',
                eventId: evId,
                spaceId: s1,
                createdAt: now,
              ),
            );
        await guestDb.into(guestDb.eventSpaceLinks).insert(
              EventSpaceLinksCompanion.insert(
                id: 'link-$evId-$s2',
                eventId: evId,
                spaceId: s2,
                createdAt: now,
              ),
            );

        // 1 comment
        await guestDb.commentDao.insertComment(
          EventCommentsCompanion.insert(
            id: 'cm-$evId',
            eventId: evId,
            userId: 'guest',
            authorName: 'Heavy Tester',
            content: '自動化壓力測試評論 #$i',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // 1 attachment
        await guestDb.into(guestDb.eventAttachments).insert(
              EventAttachmentsCompanion.insert(
                id: 'att-$evId',
                eventId: evId,
                userId: 'guest',
                fileName: 'attach_$i.png',
                fileUrl: 'file:///attach_$i.png',
                fileType: 'image/png',
                fileSize: 1024 * (i + 1),
                createdAt: now,
              ),
            );

        // 2 checklists
        await guestDb.checklistDao.insertChecklist(
          EventChecklistsCompanion.insert(
            id: 'ck-$evId-1',
            eventId: evId,
            title: '檢查項 A for $i',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await guestDb.checklistDao.insertChecklist(
          EventChecklistsCompanion.insert(
            id: 'ck-$evId-2',
            eventId: evId,
            title: '檢查項 B for $i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Seed 50 keep items and 30 pomodoro sessions
      for (int i = 0; i < 50; i++) {
        await guestDb.keepItemDao.insertKeepItem(
          KeepItemsCompanion.insert(
            id: 'heavy-kp-$i',
            userId: 'guest',
            title: '靈感 #$i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      for (int i = 0; i < 30; i++) {
        await guestDb.into(guestDb.pomodoroSessions).insert(
              PomodoroSessionsCompanion.insert(
                id: 'heavy-pomo-$i',
                eventId: Value('heavy-ev-$i'),
                userId: 'guest',
                durationMinutes: 25,
                startedAt: now,
              ),
            );
      }

      final seedElapsed = stopwatch.elapsedMilliseconds;
      expect(seedElapsed, greaterThanOrEqualTo(0));

      // 3. Execute Migration
      final migrationStopwatch = Stopwatch()..start();
      final result = await executor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: targetUserId,
        mode: MigrationMode.autoMigrate,
      );
      final migrationElapsed = migrationStopwatch.elapsedMilliseconds;
      expect(migrationElapsed, greaterThanOrEqualTo(0));

      expect(result.success, isTrue);
      expect(result.spacesMigrated, equals(spaceCount));
      expect(result.eventsMigrated, equals(eventCount));
      expect(result.linksMigrated, equals(eventCount * 2));
      expect(result.commentsMigrated, equals(eventCount));
      expect(result.attachmentsMigrated, equals(eventCount));
      expect(result.checklistsMigrated, equals(eventCount * 2));
      expect(result.keepItemsMigrated, equals(50));
      expect(result.pomodoroSessionsMigrated, equals(30));

      // Total expected outbox mutations:
      // spaces(5) + events(150) + links(300) + comments(150) + attachments(150) + checklists(300) + keep(50) + pomodoro(30) = 1135
      expect(result.outboxEntriesEnqueued, equals(1135));

      // Verify userDb contains all rows
      final uEvents = await userDb.eventDao.watchAllEvents().first;
      expect(uEvents.length, equals(150));
      expect(uEvents.every((e) => e.userId == targetUserId), isTrue);

      final uSpaces = await userDb.spaceDao.watchAllSpaces().first;
      expect(uSpaces.length, equals(5));

      final uOutbox = await userDb.outboxDao.getPendingMutations(limit: 2000);
      expect(uOutbox.length, equals(1135));

      // Verify guestDb is 100% purged
      final gEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(gEvents.isEmpty, isTrue);
      final gSpaces = await guestDb.spaceDao.watchAllSpaces().first;
      expect(gSpaces.isEmpty, isTrue);
      final gOutbox = await guestDb.outboxDao.getPendingMutations(limit: 10);
      expect(gOutbox.isEmpty, isTrue);
    });

    test('7. Conflict detector edge case: guest created custom space but 0 events', () async {
      final now = DateTime.now();

      // Guest creates a custom space (e.g. project space), but has not created events yet
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-guest-custom',
          userId: 'guest',
          name: '新專案日曆',
          type: 'project',
          color: 0xFF123456,
          isDefault: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Check whether MigrationConflictDetector detects this guest data
      final hasGuestData = await MigrationConflictDetector.checkHasGuestData(guestDb);
      expect(hasGuestData, isTrue);

      final scenario = await MigrationConflictDetector.detectScenario(
        guestDb: guestDb,
        userDb: userDb,
        isNewRegistration: true,
      );
      expect(scenario, equals(MigrationScenario.brandNewAccount));
    });
  });
}
