enum ConflictResolutionWinner {
  local,
  remote,
  tieBreaker;
}

class SyncConflictResolution<T> {
  final T winnerData;
  final ConflictResolutionWinner winner;
  final String reason;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
  final int localVersion;
  final int remoteVersion;

  const SyncConflictResolution({
    required this.winnerData,
    required this.winner,
    required this.reason,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.localVersion,
    required this.remoteVersion,
  });

  bool get isRemoteWinner => winner == ConflictResolutionWinner.remote;
  bool get isLocalWinner => winner == ConflictResolutionWinner.local;
}
