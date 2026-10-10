import '../entities/outbox_mutation.dart';

abstract class OutboxRepository {
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncAction action,
    required String payloadJson,
    String? id,
    DateTime? clientTimestamp,
    String? idempotencyKey,
  });

  Future<List<OutboxMutation>> getPendingMutations({int limit = 50});

  Future<void> markStatus(
    String mutationId,
    SyncStatus status, {
    String? errorMessage,
  });

  Future<void> markBatchSynced(List<String> mutationIds);

  Future<void> incrementRetry(String mutationId, String errorMessage);

  Future<int> getPendingCount();

  Stream<int> watchPendingCount();

  Future<void> purgeSynced({Duration olderThan = const Duration(days: 7)});
}
