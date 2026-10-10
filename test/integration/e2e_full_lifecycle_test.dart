import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/migrations/guest_migration_executor.dart';
import 'package:smart_calendar_hub/core/database/migrations/migration_models.dart';
import 'package:smart_calendar_hub/core/platform/tray_service.dart';
import 'package:smart_calendar_hub/core/platform/widget_service.dart';
import 'package:smart_calendar_hub/features/sync/application/sync_coordinator.dart';
import 'package:smart_calendar_hub/features/sync/application/widget_snapshot_exporter.dart';
import 'package:smart_calendar_hub/features/sync/data/datasources/mock_supabase_sync_client.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/remote_sync_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/outbox_mutation.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/sync_state.dart';
import 'package:smart_calendar_hub/features/sync/domain/services/idempotent_sync_engine.dart';

void main() {
  group('Feature #49: ChronoHub E2E Automated Full Lifecycle Suite (Tier 1-4)', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase guestDb;
    late AppDatabase userDb;
    late MockSupabaseSyncClient mockCloud;
    late MockWidgetSyncService mockWidgetService;
    late MockTrayService mockTrayService;

    const testUserId = 'user_e2e_verified_123';

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      guestDb = AppDatabase(dbFactory.createConnection('guest.db'));
      userDb = AppDatabase(dbFactory.createConnection('user_e2e.db'));
      mockCloud = MockSupabaseSyncClient();
      mockWidgetService = MockWidgetSyncService();
      mockTrayService = MockTrayService();
    });

    tearDown(() async {
      await guestDb.close();
      await userDb.close();
    });

    test('Full E2E Journey: Guest Creation -> Account Migration -> Cloud Outbox Sync -> LWW Realtime -> Native Widget Snapshot', () async {
      // ════════════════════════════════════════════════════════════════════════
      // Phase 1: Zero-Friction Guest Mode Data Authoring
      // ════════════════════════════════════════════════════════════════════════
      final now = DateTime.now();

      // Seed guest space
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'guest-space-1',
          userId: 'guest',
          name: 'Personal Life',
          type: 'personal',
          color: 0xFF6366F1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed guest event
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'guest-evt-1',
          userId: 'guest',
          title: 'Doctor Appointment',
          startTime: Value(DateTime(now.year, now.month, now.day, 10, 0)),
          endTime: Value(DateTime(now.year, now.month, now.day, 11, 0)),
          isAnchored: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Link space
      await guestDb.eventSpaceLinkDao.linkEventToSpaces('guest-evt-1', ['guest-space-1']);

      // Add checklist item
      await guestDb.checklistDao.insertChecklist(
        EventChecklistsCompanion.insert(
          id: 'guest-chk-1',
          eventId: 'guest-evt-1',
          title: 'Bring insurance card',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Add Keep idea
      await guestDb.keepItemDao.insertKeepItem(
        KeepItemsCompanion.insert(
          id: 'guest-keep-1',
          userId: 'guest',
          title: 'Buy ergonomic keyboard',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Enqueue guest Outbox mutations
      final guestOutboxRepo = OutboxRepositoryImpl(guestDb);
      await guestOutboxRepo.enqueue(
        id: 'mut-g1',
        tableName: 'calendar_events',
        recordId: 'guest-evt-1',
        action: SyncAction.insert,
        payloadJson: '{"id":"guest-evt-1","title":"Doctor Appointment"}',
      );

      expect(await guestDb.eventDao.watchAllEvents().first, hasLength(1));
      expect(await guestOutboxRepo.getPendingCount(), equals(1));

      // ════════════════════════════════════════════════════════════════════════
      // Phase 2: User Signs Up -> Atomic Transactional Migration to User DB
      // ════════════════════════════════════════════════════════════════════════
      final migrationExecutor = GuestMigrationExecutor();
      final migrationResult = await migrationExecutor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: testUserId,
        mode: MigrationMode.autoMigrate,
      );

      expect(migrationResult.spacesMigrated, equals(1));
      expect(migrationResult.eventsMigrated, equals(1));
      expect(migrationResult.linksMigrated, equals(1));
      expect(migrationResult.checklistsMigrated, equals(1));
      expect(migrationResult.keepItemsMigrated, equals(1));

      // Guest DB is wiped cleanly
      expect(await guestDb.eventDao.watchAllEvents().first, isEmpty);

      // User DB now possesses all migrated records under new user ID
      final userEvents = await userDb.eventDao.watchAllEvents().first;
      expect(userEvents, hasLength(1));
      expect(userEvents.first.userId, equals(testUserId));
      expect(userEvents.first.title, equals('Doctor Appointment'));

      // ════════════════════════════════════════════════════════════════════════
      // Phase 3: Local-First Outbox Synchronization to Supabase Cloud
      // ════════════════════════════════════════════════════════════════════════
      final userOutboxRepo = OutboxRepositoryImpl(userDb);
      final remoteRepo = RemoteSyncRepositoryImpl(mockCloud);
      final syncEngine = IdempotentSyncEngine(
        outboxRepo: userOutboxRepo,
        remoteRepo: remoteRepo,
        deviceId: 'device-desktop-test',
      );

      final coordinator = SyncCoordinator(
        outboxRepo: userOutboxRepo,
        remoteRepo: remoteRepo,
        db: userDb,
        syncEngine: syncEngine,
        clientId: 'device-desktop-test',
      );

      // Trigger cloud sync
      final syncResult = await coordinator.triggerManualSync(testUserId);
      expect(syncResult, isA<SyncSuccess>());

      // Cloud now mirrors the event
      final cloudEvents = mockCloud.getTableData('calendar_events');
      expect(cloudEvents.containsKey('guest-evt-1'), isTrue);
      expect(await userOutboxRepo.getPendingCount(), equals(0));

      // ════════════════════════════════════════════════════════════════════════
      // Phase 4: Remote Realtime Mutation with LWW Arbitration
      // ════════════════════════════════════════════════════════════════════════
      coordinator.startAutoSync(userId: testUserId);

      // Simulate remote user updating event title on iPhone at later timestamp
      final remoteLaterTime = now.add(const Duration(minutes: 10));
      await mockCloud.upsert(
        table: 'calendar_events',
        data: {
          'id': 'guest-evt-1',
          'user_id': testUserId,
          'title': 'Doctor Appointment (Rescheduled Room 302)',
          'start_time': DateTime(now.year, now.month, now.day, 10, 0).toIso8601String(),
          'end_time': DateTime(now.year, now.month, now.day, 11, 0).toIso8601String(),
          'is_all_day': false,
          'is_anchored': true,
          'status': 'pending',
          'priority': 1,
          'estimated_minutes': 60,
          'actual_minutes': 0,
          'version': 2,
          'created_at': now.toIso8601String(),
          'updated_at': remoteLaterTime.toIso8601String(),
          'is_deleted': false,
        },
      );

      // Allow microtask queue for realtime stream delivery
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updatedLocalEvent = await (userDb.select(userDb.calendarEvents)
            ..where((t) => t.id.equals('guest-evt-1')))
          .getSingle();

      expect(updatedLocalEvent.title, equals('Doctor Appointment (Rescheduled Room 302)'));
      expect(updatedLocalEvent.version, equals(2));

      // ════════════════════════════════════════════════════════════════════════
      // Phase 5: Native Ecosystem Export (HomeWidget Snapshot & Tray)
      // ════════════════════════════════════════════════════════════════════════
      final widgetExporter = WidgetSnapshotExporter(
        db: userDb,
        widgetService: mockWidgetService,
      );

      final snapshot = await widgetExporter.exportSnapshot();
      expect(snapshot.events, hasLength(1));
      expect(snapshot.events.first.title, contains('Rescheduled Room 302'));
      expect(snapshot.isWithinSizeLimit, isTrue);
      expect(snapshot.byteSize, lessThan(10 * 1024)); // <10KB

      // Verify Tray integration
      await mockTrayService.initializeTray(tooltip: 'ChronoHub Calendar');
      expect(mockTrayService.isInitialized, isTrue);
      await mockTrayService.showMiniCalendar();
      expect(await mockTrayService.isMiniCalendarVisible(), isTrue);

      coordinator.dispose();
    });
  });
}
