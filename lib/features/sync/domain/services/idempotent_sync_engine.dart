import 'dart:async';
import 'package:uuid/uuid.dart';
import '../entities/batch_sync_payload.dart';
import '../entities/sync_state.dart';
import '../repositories/outbox_repository.dart';
import '../repositories/remote_sync_repository.dart';

class IdempotentSyncEngine {
  final OutboxRepository _outboxRepo;
  final RemoteSyncRepository _remoteRepo;
  final String deviceId;
  final String Function() _uuidGenerator;

  IdempotentSyncEngine({
    required OutboxRepository outboxRepo,
    required RemoteSyncRepository remoteRepo,
    required this.deviceId,
    String Function()? uuidGenerator,
  })  : _outboxRepo = outboxRepo,
        _remoteRepo = remoteRepo,
        _uuidGenerator = uuidGenerator ?? const Uuid().v4;

  /// Executes a full synchronization cycle for pending outbox mutations
  Future<SyncState> syncPendingOutbox({
    required String userId,
    int batchSize = 50,
  }) async {
    final isOnline = await _remoteRepo.checkConnectivity();
    if (!isOnline) {
      final pendingCount = await _outboxRepo.getPendingCount();
      return SyncIdle(pendingOutboxCount: pendingCount);
    }

    final pendingMutations = await _outboxRepo.getPendingMutations(limit: batchSize);
    if (pendingMutations.isEmpty) {
      return SyncIdle(lastSyncedAt: DateTime.now(), pendingOutboxCount: 0);
    }

    // Generate unique idempotency key for this batch (Feature #43)
    final idempotencyKey = _uuidGenerator();

    final payload = BatchSyncPayload(
      idempotencyKey: idempotencyKey,
      deviceId: deviceId,
      userId: userId,
      sentAt: DateTime.now(),
      mutations: pendingMutations,
    );

    try {
      final result = await _remoteRepo.pushBatchMutations(payload);

      if (result.isSuccess) {
        // Mark all mutations in batch as synced
        final syncedIds = pendingMutations.map((m) => m.id).toList();
        await _outboxRepo.markBatchSynced(syncedIds);

        final remainingPending = await _outboxRepo.getPendingCount();
        if (remainingPending > 0) {
          // If there are more items, continue next batch recursively
          return await syncPendingOutbox(userId: userId, batchSize: batchSize);
        }

        return SyncSuccess(
          syncedCount: pendingMutations.length,
          syncedAt: DateTime.now(),
        );
      } else {
        // Handle partial or complete rejection
        for (final rejectedId in result.rejectedMutationIds) {
          await _outboxRepo.incrementRetry(
            rejectedId,
            result.errorMessage ?? 'Remote rejected mutation',
          );
        }

        final nonRejected = pendingMutations
            .where((m) => !result.rejectedMutationIds.contains(m.id))
            .map((m) => m.id)
            .toList();
        await _outboxRepo.markBatchSynced(nonRejected);

        return SyncFailure(
          error: result.errorMessage ?? 'Batch sync partially failed',
          failedCount: result.rejectedMutationIds.length,
          failedAt: DateTime.now(),
        );
      }
    } catch (e) {
      // Mark all mutations as retry incremented on network/server exception
      for (final m in pendingMutations) {
        await _outboxRepo.incrementRetry(m.id, e.toString());
      }
      return SyncFailure(
        error: e.toString(),
        failedCount: pendingMutations.length,
        failedAt: DateTime.now(),
      );
    }
  }
}
