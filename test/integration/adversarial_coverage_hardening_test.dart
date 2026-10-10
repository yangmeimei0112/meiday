import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/widget_service.dart';
import 'package:smart_calendar_hub/features/calendar/domain/entities/schedule_models.dart';
import 'package:smart_calendar_hub/features/calendar/domain/services/auto_cascade_scheduler.dart';
import 'package:smart_calendar_hub/features/sync/application/widget_snapshot_exporter.dart';
import 'package:smart_calendar_hub/features/sync/data/datasources/mock_supabase_sync_client.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/remote_sync_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/outbox_mutation.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/sync_state.dart';
import 'package:smart_calendar_hub/features/sync/domain/services/idempotent_sync_engine.dart';
import 'package:smart_calendar_hub/features/sync/domain/services/lww_conflict_resolver.dart';

void main() {
  group('Feature #50: ChronoHub Tier 5 Adversarial Coverage Hardening Suite', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase db;
    late MockSupabaseSyncClient mockCloud;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      db = AppDatabase(dbFactory.createConnection('adversarial_hardening.db'));
      mockCloud = MockSupabaseSyncClient();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Concurrency & Network Flapping Storm: 100 interleaved mutations with retries', () async {
      final outboxRepo = OutboxRepositoryImpl(db);
      final remoteRepo = RemoteSyncRepositoryImpl(mockCloud);
      final engine = IdempotentSyncEngine(
        outboxRepo: outboxRepo,
        remoteRepo: remoteRepo,
        deviceId: 'stress-device-01',
      );

      // Concurrent enqueue storm: 100 mutations in parallel
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(outboxRepo.enqueue(
          id: 'mut-stress-$i',
          tableName: 'calendar_events',
          recordId: 'evt-stress-$i',
          action: (i % 3 == 0)
              ? SyncAction.insert
              : (i % 3 == 1)
                  ? SyncAction.update
                  : SyncAction.delete,
          payloadJson: jsonEncode({'id': 'evt-stress-$i', 'index': i}),
        ));
      }
      await Future.wait(futures);

      expect(await outboxRepo.getPendingCount(), equals(100));

      // Network flaps offline
      mockCloud.isNetworkAvailable = false;
      final offlineRes = await engine.syncPendingOutbox(userId: 'stress-user');
      expect(offlineRes, isA<SyncIdle>());
      expect(await outboxRepo.getPendingCount(), equals(100));

      // Network restores
      mockCloud.isNetworkAvailable = true;
      final onlineRes = await engine.syncPendingOutbox(userId: 'stress-user', batchSize: 50);
      expect(onlineRes, isA<SyncSuccess>());

      // All 100 items processed across 2 automatic batches
      expect(await outboxRepo.getPendingCount(), equals(0));
    });

    test('2. Boundary & Leap Year Scheduling: Leap Day (Feb 29) and midnight transitions', () {
      final scheduler = AutoCascadeSchedulerImpl();

      // Leap day test: 2028-02-29
      final leapDayStart = DateTime(2028, 2, 29, 23, 30);
      final leapDayEnd = DateTime(2028, 3, 1, 0, 30);

      final leapEvent = CalendarEvent(
        id: 'evt-leap',
        userId: 'user-1',
        title: 'Leap Night Gala',
        startTime: leapDayStart,
        endTime: leapDayEnd,
        isAnchored: true,
        estimatedMinutes: 60,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final nextDayTask = CalendarEvent(
        id: 'evt-next-day',
        userId: 'user-1',
        title: 'Morning Post-Gala Clean',
        startTime: DateTime(2028, 3, 1, 0, 15),
        endTime: DateTime(2028, 3, 1, 1, 15),
        isAnchored: false,
        estimatedMinutes: 60,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = scheduler.schedule(
        existingEvents: [leapEvent, nextDayTask],
        movingEvent: nextDayTask,
        targetStartTime: DateTime(2028, 3, 1, 0, 0),
      );

      // Scheduler detects anchor overlap across midnight and proposes buffer shifts
      expect(result.conflicts.isNotEmpty || result.modifiedEvents.isNotEmpty, isTrue);
    });

    test('3. Extreme Snapshot Payload Stress: 200 large events strictly stay under 5MB', () async {
      final mockWidgetService = MockWidgetSyncService();
      final exporter = WidgetSnapshotExporter(
        db: db,
        widgetService: mockWidgetService,
      );

      final today = DateTime.now();

      // Insert 200 events with realistic descriptions and titles
      for (int i = 0; i < 200; i++) {
        await db.eventDao.insertEvent(
          CalendarEventsCompanion.insert(
            id: 'evt-bulk-$i',
            userId: 'user-stress',
            title: 'Large Event Title #$i - Cross-Platform Architecture Review Session',
            description: Value('Detailed notes on distributed SQLite replication, CRDT semantics, and Supabase RLS #$i'),
            startTime: Value(DateTime(today.year, today.month, today.day, 8 + (i % 12), 0)),
            endTime: Value(DateTime(today.year, today.month, today.day, 8 + (i % 12), 30)),
            estimatedMinutes: const Value(30),
            createdAt: today,
            updatedAt: today,
          ),
        );
      }

      final snapshot = await exporter.exportSnapshot();
      expect(snapshot.events, hasLength(200));

      // Invariant: Snapshot MUST stay < 5MB (under 200KB for 200 events)
      expect(snapshot.byteSize, lessThan(5 * 1024 * 1024));
      expect(snapshot.byteSize, lessThan(200 * 1024));
      expect(snapshot.isWithinSizeLimit, isTrue);
    });

    test('4. LWW Microsecond Tie-Breaker Stress Invariant', () {
      const resolver = LwwConflictResolver();
      final exactTime = DateTime.utc(2026, 10, 10, 12, 0, 0, 123, 456);

      // Ensure that even at identical microsecond precision and identical version,
      // the deterministic tie-breaker guarantees identical decision across any node order
      final outcome1 = resolver.resolve<int>(
        localData: 1,
        remoteData: 2,
        localUpdatedAt: exactTime,
        remoteUpdatedAt: exactTime,
        localVersion: 5,
        remoteVersion: 5,
        localClientId: 'node-alpha',
        remoteClientId: 'node-beta',
      );

      final outcome2 = resolver.resolve<int>(
        localData: 2,
        remoteData: 1,
        localUpdatedAt: exactTime,
        remoteUpdatedAt: exactTime,
        localVersion: 5,
        remoteVersion: 5,
        localClientId: 'node-beta',
        remoteClientId: 'node-alpha',
      );

      // Node alpha is strictly lexicographically smaller than node beta
      expect(outcome1.isLocalWinner, isTrue); // In outcome1, local is node-alpha
      expect(outcome2.isRemoteWinner, isTrue); // In outcome2, remote is node-alpha
      // Both nodes converge to the exact same winner: node-alpha's data!
    });
  });
}
