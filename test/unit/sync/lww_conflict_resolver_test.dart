import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/sync_conflict.dart';
import 'package:smart_calendar_hub/features/sync/domain/services/lww_conflict_resolver.dart';

void main() {
  group('LwwConflictResolver Unit Tests', () {
    const resolver = LwwConflictResolver();

    final baseTime = DateTime(2026, 10, 10, 12, 0, 0);

    test('Remote timestamp newer awards victory to remote', () {
      final res = resolver.resolve<String>(
        localData: 'local_v1',
        remoteData: 'remote_v2',
        localUpdatedAt: baseTime,
        remoteUpdatedAt: baseTime.add(const Duration(minutes: 5)),
        localVersion: 1,
        remoteVersion: 1,
        localClientId: 'client-A',
        remoteClientId: 'client-B',
      );

      expect(res.winner, equals(ConflictResolutionWinner.remote));
      expect(res.winnerData, equals('remote_v2'));
      expect(res.isRemoteWinner, isTrue);
      expect(res.reason, contains('Remote timestamp is newer'));
    });

    test('Local timestamp newer awards victory to local', () {
      final res = resolver.resolve<String>(
        localData: 'local_v2',
        remoteData: 'remote_v1',
        localUpdatedAt: baseTime.add(const Duration(minutes: 5)),
        remoteUpdatedAt: baseTime,
        localVersion: 1,
        remoteVersion: 1,
        localClientId: 'client-A',
        remoteClientId: 'client-B',
      );

      expect(res.winner, equals(ConflictResolutionWinner.local));
      expect(res.winnerData, equals('local_v2'));
      expect(res.isLocalWinner, isTrue);
      expect(res.reason, contains('Local timestamp is newer'));
    });

    test('Identical timestamps award victory to higher version', () {
      final resRemoteHigher = resolver.resolve<String>(
        localData: 'local_v1',
        remoteData: 'remote_v3',
        localUpdatedAt: baseTime,
        remoteUpdatedAt: baseTime,
        localVersion: 1,
        remoteVersion: 3,
        localClientId: 'client-A',
        remoteClientId: 'client-B',
      );

      expect(resRemoteHigher.winner, equals(ConflictResolutionWinner.remote));
      expect(resRemoteHigher.winnerData, equals('remote_v3'));
      expect(resRemoteHigher.reason, contains('remote version is higher'));

      final resLocalHigher = resolver.resolve<String>(
        localData: 'local_v5',
        remoteData: 'remote_v2',
        localUpdatedAt: baseTime,
        remoteUpdatedAt: baseTime,
        localVersion: 5,
        remoteVersion: 2,
        localClientId: 'client-A',
        remoteClientId: 'client-B',
      );

      expect(resLocalHigher.winner, equals(ConflictResolutionWinner.local));
      expect(resLocalHigher.winnerData, equals('local_v5'));
      expect(resLocalHigher.reason, contains('local version is higher'));
    });

    test('Complete tie resolves deterministically via client ID lexicographical order', () {
      // client-A <= client-B -> local wins
      final resLocalTie = resolver.resolve<String>(
        localData: 'local_tied',
        remoteData: 'remote_tied',
        localUpdatedAt: baseTime,
        remoteUpdatedAt: baseTime,
        localVersion: 2,
        remoteVersion: 2,
        localClientId: 'client-A',
        remoteClientId: 'client-B',
      );

      expect(resLocalTie.winner, equals(ConflictResolutionWinner.local));
      expect(resLocalTie.winnerData, equals('local_tied'));
      expect(resLocalTie.reason, contains('deterministic client ID tie-breaker chose local'));

      // client-Z > client-A -> remote wins
      final resRemoteTie = resolver.resolve<String>(
        localData: 'local_tied',
        remoteData: 'remote_tied',
        localUpdatedAt: baseTime,
        remoteUpdatedAt: baseTime,
        localVersion: 2,
        remoteVersion: 2,
        localClientId: 'client-Z',
        remoteClientId: 'client-A',
      );

      expect(resRemoteTie.winner, equals(ConflictResolutionWinner.remote));
      expect(resRemoteTie.winnerData, equals('remote_tied'));
      expect(resRemoteTie.reason, contains('deterministic client ID tie-breaker chose remote'));
    });
  });
}
