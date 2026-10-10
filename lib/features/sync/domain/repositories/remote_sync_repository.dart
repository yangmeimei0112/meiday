import '../entities/batch_sync_payload.dart';

abstract class RemoteSyncRepository {
  Future<bool> checkConnectivity();

  Future<BatchSyncResult> pushBatchMutations(BatchSyncPayload payload);

  Future<List<Map<String, dynamic>>> pullRemoteChanges({
    required String tableName,
    required DateTime sinceTimestamp,
    int limit = 100,
  });

  Stream<Map<String, dynamic>> watchRealtimeTableChanges(String tableName);

  Future<void> acknowledgeIdempotencyKey({
    required String idempotencyKey,
    required String deviceId,
    required int mutationCount,
  });
}
