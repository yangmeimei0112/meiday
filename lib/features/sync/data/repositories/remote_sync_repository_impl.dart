import '../../domain/entities/batch_sync_payload.dart';
import '../../domain/repositories/remote_sync_repository.dart';
import '../datasources/supabase_sync_client.dart';

class RemoteSyncRepositoryImpl implements RemoteSyncRepository {
  final SupabaseSyncClient _client;

  RemoteSyncRepositoryImpl(this._client);

  @override
  Future<bool> checkConnectivity() async {
    try {
      return await _client.ping();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BatchSyncResult> pushBatchMutations(BatchSyncPayload payload) async {
    return await _client.executeBatchRpc(payload);
  }

  @override
  Future<List<Map<String, dynamic>>> pullRemoteChanges({
    required String tableName,
    required DateTime sinceTimestamp,
    int limit = 100,
  }) async {
    return await _client.query(
      table: tableName,
      since: sinceTimestamp,
      limit: limit,
    );
  }

  @override
  Stream<Map<String, dynamic>> watchRealtimeTableChanges(String tableName) {
    return _client.realtimeStream(tableName);
  }

  @override
  Future<void> acknowledgeIdempotencyKey({
    required String idempotencyKey,
    required String deviceId,
    required int mutationCount,
  }) async {
    // Acknowledges receipt on the remote server
    await _client.upsert(
      table: 'processed_idempotency_keys',
      data: {
        'key': idempotencyKey,
        'device_id': deviceId,
        'applied_count': mutationCount,
        'processed_at': DateTime.now().toIso8601String(),
      },
    );
  }
}
