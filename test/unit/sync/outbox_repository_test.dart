import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/sync/data/repositories/outbox_repository_impl.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/outbox_mutation.dart';

void main() {
  group('OutboxRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase db;
    late OutboxRepositoryImpl repo;

    setUp(() {
      factory = InMemoryDatabaseConnectionFactory();
      db = AppDatabase(factory.createConnection('test_outbox.db'));
      repo = OutboxRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('enqueue inserts mutation with pending status and retrieves it', () async {
      await repo.enqueue(
        id: 'mut-1',
        tableName: 'calendar_events',
        recordId: 'evt-100',
        action: SyncAction.insert,
        payloadJson: '{"title":"Team Standup"}',
      );

      final pending = await repo.getPendingMutations();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('mut-1'));
      expect(pending.first.tableName, equals('calendar_events'));
      expect(pending.first.recordId, equals('evt-100'));
      expect(pending.first.action, equals(SyncAction.insert));
      expect(pending.first.status, equals(SyncStatus.pending));
    });

    test('markStatus updates mutation status and error message', () async {
      await repo.enqueue(
        id: 'mut-2',
        tableName: 'calendar_spaces',
        recordId: 'space-1',
        action: SyncAction.update,
        payloadJson: '{"name":"Family"}',
      );

      await repo.markStatus('mut-2', SyncStatus.processing);
      var rows = await repo.getPendingMutations();
      // processing is not pending or failed, so it won't be returned by default pending query
      expect(rows.isEmpty, isTrue);

      await repo.markStatus('mut-2', SyncStatus.failed, errorMessage: 'Timeout 504');
      rows = await repo.getPendingMutations();
      expect(rows.length, equals(1));
      expect(rows.first.status, equals(SyncStatus.failed));
      expect(rows.first.errorMessage, equals('Timeout 504'));
    });

    test('markBatchSynced updates all IDs atomically to synced', () async {
      await repo.enqueue(
        id: 'mut-3',
        tableName: 'event_comments',
        recordId: 'comm-1',
        action: SyncAction.insert,
        payloadJson: '{}',
      );
      await repo.enqueue(
        id: 'mut-4',
        tableName: 'event_comments',
        recordId: 'comm-2',
        action: SyncAction.insert,
        payloadJson: '{}',
      );

      expect(await repo.getPendingCount(), equals(2));

      await repo.markBatchSynced(['mut-3', 'mut-4']);

      expect(await repo.getPendingCount(), equals(0));
    });

    test('incrementRetry increments count and flags mutation as failed', () async {
      await repo.enqueue(
        id: 'mut-5',
        tableName: 'keep_items',
        recordId: 'keep-1',
        action: SyncAction.delete,
        payloadJson: '{}',
      );

      await repo.incrementRetry('mut-5', 'Connection refused');
      var list = await repo.getPendingMutations();
      expect(list.first.retryCount, equals(1));
      expect(list.first.status, equals(SyncStatus.failed));

      await repo.incrementRetry('mut-5', 'Connection reset by peer');
      list = await repo.getPendingMutations();
      expect(list.first.retryCount, equals(2));
      expect(list.first.errorMessage, equals('Connection reset by peer'));
    });

    test('purgeSynced removes records older than cutoff duration', () async {
      await repo.enqueue(
        id: 'mut-old',
        tableName: 'calendar_events',
        recordId: 'evt-old',
        action: SyncAction.insert,
        payloadJson: '{}',
      );
      await repo.markStatus('mut-old', SyncStatus.synced);

      // Purge with zero duration deletes all synced records
      await repo.purgeSynced(olderThan: Duration.zero);

      final remaining = await (db.select(db.syncOutbox)..where((t) => t.id.equals('mut-old'))).get();
      expect(remaining.isEmpty, isTrue);
    });
  });
}
