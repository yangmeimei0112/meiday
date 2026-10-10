import '../entities/sync_conflict.dart';

class LwwConflictResolver {
  const LwwConflictResolver();

  /// Resolves conflict between local and remote entity versions using Last-Write-Wins (LWW)
  /// with deterministic tie-breaking.
  SyncConflictResolution<T> resolve<T>({
    required T localData,
    required T remoteData,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required int localVersion,
    required int remoteVersion,
    required String localClientId,
    required String remoteClientId,
  }) {
    // 1. Primary rule: Timestamp comparison
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return SyncConflictResolution<T>(
        winnerData: remoteData,
        winner: ConflictResolutionWinner.remote,
        reason: 'Remote timestamp is newer (${remoteUpdatedAt.toIso8601String()} > ${localUpdatedAt.toIso8601String()})',
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    } else if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return SyncConflictResolution<T>(
        winnerData: localData,
        winner: ConflictResolutionWinner.local,
        reason: 'Local timestamp is newer (${localUpdatedAt.toIso8601String()} > ${remoteUpdatedAt.toIso8601String()})',
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }

    // 2. Secondary rule: Version number comparison when timestamps are identical
    if (remoteVersion > localVersion) {
      return SyncConflictResolution<T>(
        winnerData: remoteData,
        winner: ConflictResolutionWinner.remote,
        reason: 'Timestamps identical, remote version is higher ($remoteVersion > $localVersion)',
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    } else if (localVersion > remoteVersion) {
      return SyncConflictResolution<T>(
        winnerData: localData,
        winner: ConflictResolutionWinner.local,
        reason: 'Timestamps identical, local version is higher ($localVersion > $remoteVersion)',
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }

    // 3. Tertiary rule: Deterministic client ID tie-breaker
    final cmp = localClientId.compareTo(remoteClientId);
    if (cmp <= 0) {
      return SyncConflictResolution<T>(
        winnerData: localData,
        winner: ConflictResolutionWinner.local,
        reason: 'Complete tie: deterministic client ID tie-breaker chose local ($localClientId <= $remoteClientId)',
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    } else {
      return SyncConflictResolution<T>(
        winnerData: remoteData,
        winner: ConflictResolutionWinner.remote,
        reason: 'Complete tie: deterministic client ID tie-breaker chose remote ($remoteClientId < $localClientId)',
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }
  }
}
