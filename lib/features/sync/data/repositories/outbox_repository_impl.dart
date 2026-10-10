import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/outbox_mutation.dart';
import '../../domain/repositories/outbox_repository.dart';

class OutboxRepositoryImpl implements OutboxRepository {
  final AppDatabase _db;

  OutboxRepositoryImpl(this._db);

  @override
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncAction action,
    required String payloadJson,
    String? id,
    DateTime? clientTimestamp,
    String? idempotencyKey,
  }) async {
    final mutationId = id ?? 'mut_${DateTime.now().microsecondsSinceEpoch}';

    await _db.outboxDao.enqueueMutation(
      id: mutationId,
      tableName: tableName,
      recordId: recordId,
      action: action.toDbString(),
      payloadJson: payloadJson,
    );
  }

  @override
  Future<List<OutboxMutation>> getPendingMutations({int limit = 50}) async {
    final rows = await _db.outboxDao.getPendingMutations(limit: limit);
    return rows.map((r) => OutboxMutation(
          id: r.id,
          tableName: r.targetTable,
          recordId: r.recordId,
          action: SyncAction.fromString(r.action),
          payloadJson: r.payloadJson,
          clientTimestamp: r.clientTimestamp,
          retryCount: r.retryCount,
          status: SyncStatus.fromString(r.status),
          errorMessage: r.errorMessage,
        )).toList();
  }

  @override
  Future<void> markStatus(
    String mutationId,
    SyncStatus status, {
    String? errorMessage,
  }) async {
    await _db.outboxDao.markStatus(
      mutationId,
      status.name,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> markBatchSynced(List<String> mutationIds) async {
    if (mutationIds.isEmpty) return;
    await _db.batch((batch) {
      for (final id in mutationIds) {
        batch.update(
          _db.syncOutbox,
          const SyncOutboxCompanion(
            status: Value('synced'),
          ),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  @override
  Future<void> incrementRetry(String mutationId, String errorMessage) async {
    final existing = await (_db.select(_db.syncOutbox)
          ..where((t) => t.id.equals(mutationId)))
        .getSingleOrNull();

    final currentRetries = existing?.retryCount ?? 0;
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(mutationId))).write(
      SyncOutboxCompanion(
        retryCount: Value(currentRetries + 1),
        status: const Value('failed'),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  @override
  Future<int> getPendingCount() async {
    final rows = await (_db.select(_db.syncOutbox)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed')))
        .get();
    return rows.length;
  }

  @override
  Stream<int> watchPendingCount() {
    return _db.outboxDao.watchPendingCount();
  }

  @override
  Future<void> purgeSynced({Duration olderThan = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await (_db.delete(_db.syncOutbox)
          ..where((t) => t.status.equals('synced') & t.clientTimestamp.isSmallerOrEqualValue(cutoff)))
        .go();
  }
}
