import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/sync/application/sync_coordinator.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/sync_state.dart';
import 'package:smart_calendar_hub/features/sync/presentation/providers/sync_providers.dart';
import 'package:smart_calendar_hub/features/sync/presentation/widgets/sync_status_indicator.dart';

class _MockSyncCoordinator extends StateNotifier<SyncState> implements SyncCoordinator {
  _MockSyncCoordinator(super.initialState);

  @override
  SyncState get currentState => state;

  @override
  Future<SyncState> triggerManualSync(String userId) async => state;

  @override
  void startAutoSync({required String userId, Duration interval = const Duration(seconds: 30)}) {}

  @override
  void stopAutoSync() {}
}

void main() {
  group('SyncStatusIndicator Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      testDb = AppDatabase(dbFactory.createConnection('test_sync_indicator.db'));
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('Renders synced badge when outbox is empty and status is idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            syncCoordinatorProvider.overrideWith((ref) => _MockSyncCoordinator(const SyncIdle())),
            pendingOutboxCountStreamProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: SyncStatusIndicator()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('雲端已同步'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('Renders in-progress badge during active synchronization', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            syncCoordinatorProvider.overrideWith(
              (ref) => _MockSyncCoordinator(const SyncInProgress(totalCount: 5, processedCount: 3)),
            ),
            pendingOutboxCountStreamProvider.overrideWith((ref) => Stream.value(2)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: SyncStatusIndicator()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('同步中 (3/5)'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('Renders pending count badge when there are offline mutations', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            syncCoordinatorProvider.overrideWith((ref) => _MockSyncCoordinator(const SyncIdle())),
            pendingOutboxCountStreamProvider.overrideWith((ref) => Stream.value(4)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: SyncStatusIndicator()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('4 筆離線佇列'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
