sealed class SyncState {
  const SyncState();
}

class SyncIdle extends SyncState {
  final DateTime? lastSyncedAt;
  final int pendingOutboxCount;

  const SyncIdle({this.lastSyncedAt, this.pendingOutboxCount = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncIdle &&
          other.lastSyncedAt == lastSyncedAt &&
          other.pendingOutboxCount == pendingOutboxCount;

  @override
  int get hashCode => Object.hash(lastSyncedAt, pendingOutboxCount);
}

class SyncInProgress extends SyncState {
  final int totalCount;
  final int processedCount;

  const SyncInProgress({required this.totalCount, required this.processedCount});

  double get progress => totalCount > 0 ? processedCount / totalCount : 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncInProgress &&
          other.totalCount == totalCount &&
          other.processedCount == processedCount;

  @override
  int get hashCode => Object.hash(totalCount, processedCount);
}

class SyncSuccess extends SyncState {
  final int syncedCount;
  final DateTime syncedAt;

  const SyncSuccess({required this.syncedCount, required this.syncedAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncSuccess &&
          other.syncedCount == syncedCount &&
          other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(syncedCount, syncedAt);
}

class SyncFailure extends SyncState {
  final String error;
  final int failedCount;
  final DateTime failedAt;

  const SyncFailure({
    required this.error,
    required this.failedCount,
    required this.failedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncFailure &&
          other.error == error &&
          other.failedCount == failedCount &&
          other.failedAt == failedAt;

  @override
  int get hashCode => Object.hash(error, failedCount, failedAt);
}
