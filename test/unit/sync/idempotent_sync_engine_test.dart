import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/sync/data/datasources/mock_supabase_sync_client.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/remote_sync_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/outbox_mutation.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/sync_state.dart';
import 'package:smart_calendar_hub/features/sync/domain/services/idempotent_sync_engine.dart';

void main() {
  group('IdempotentSyncEngine Unit Tests', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase db;
    late OutboxRepositoryImpl outboxRepo;
    late MockSupabaseSyncClient mockSupabase;
    late RemoteSyncRepositoryImpl remoteRepo;
    late IdempotentSyncEngine engine;

    int uuidCounter = 0;

    setUp(() {
      uuidCounter = 0;
      factory = InMemoryDatabaseConnectionFactory();
      db = AppDatabase(factory.createConnection('test_sync_engine.db'));
      outboxRepo = OutboxRepositoryImpl(db);
      mockSupabase = MockSupabaseSyncClient();
      remoteRepo = RemoteSyncRepositoryImpl(mockSupabase);
      engine = IdempotentSyncEngine(
        outboxRepo: outboxRepo,
        remoteRepo: remoteRepo,
        deviceId: 'device-test-1',
        uuidGenerator: () => 'idemp-key-${++uuidCounter}',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('syncPendingOutbox returns SyncIdle with count when offline', () async {
      mockSupabase.isNetworkAvailable = false;
      await outboxRepo.enqueue(
        id: 'mut-1',
        tableName: 'calendar_events',
        recordId: 'evt-1',
        action: SyncAction.insert,
        payloadJson: '{"title":"Offline event"}',
      );

      final state = await engine.syncPendingOutbox(userId: 'user-1');
      expect(state, isA<SyncIdle>());
      expect((state as SyncIdle).pendingOutboxCount, equals(1));
    });

    test('syncPendingOutbox pushes mutations, updates remote and marks outbox synced', () async {
      await outboxRepo.enqueue(
        id: 'mut-2',
        tableName: 'calendar_events',
        recordId: 'evt-2',
        action: SyncAction.insert,
        payloadJson: '{"id":"evt-2","title":"Sync Meeting"}',
      );

      final state = await engine.syncPendingOutbox(userId: 'user-1');
      expect(state, isA<SyncSuccess>());
      expect((state as SyncSuccess).syncedCount, equals(1));

      // Check remote database
      final remoteEvents = mockSupabase.getTableData('calendar_events');
      expect(remoteEvents.containsKey('evt-2'), isTrue);
      expect(remoteEvents['evt-2']?['title'], equals('Sync Meeting'));

      // Check local outbox marked synced
      expect(await outboxRepo.getPendingCount(), equals(0));
    });

    test('Feature #43: Idempotent replay skips duplicates gracefully without error', () async {
      // Direct call with duplicate idempotency key
      final fixedEngine = IdempotentSyncEngine(
        outboxRepo: outboxRepo,
        remoteRepo: remoteRepo,
        deviceId: 'device-test-1',
        uuidGenerator: () => 'idemp-key-constant',
      );

      await outboxRepo.enqueue(
        id: 'mut-dup',
        tableName: 'calendar_spaces',
        recordId: 'space-dup',
        action: SyncAction.insert,
        payloadJson: '{"id":"space-dup","name":"Duplicate Test"}',
      );

      final firstRes = await fixedEngine.syncPendingOutbox(userId: 'user-1');
      expect(firstRes, isA<SyncSuccess>());

      // Add another mutation but reuse same idempotency key (simulating network retry glitch)
      await outboxRepo.enqueue(
        id: 'mut-dup-2',
        tableName: 'calendar_spaces',
        recordId: 'space-dup-2',
        action: SyncAction.insert,
        payloadJson: '{"id":"space-dup-2","name":"Duplicate Test 2"}',
      );

      final secondRes = await fixedEngine.syncPendingOutbox(userId: 'user-1');
      // Second run detects duplicate idempotency key, skips gracefully and marks synced
      expect(secondRes, isA<SyncSuccess>());
    });

    test('Handles remote exception and increments mutation retryCount', () async {
      await outboxRepo.enqueue(
        id: 'mut-bad',
        tableName: 'calendar_events',
        recordId: 'evt-bad',
        action: SyncAction.insert,
        payloadJson: 'INVALID_JSON_FOR_UPSERT',
      );

      final state = await engine.syncPendingOutbox(userId: 'user-1');
      expect(state, isA<SyncFailure>());

      final pending = await outboxRepo.getPendingMutations();
      expect(pending.first.retryCount, greaterThanOrEqualTo(1));
    });
  });
}
