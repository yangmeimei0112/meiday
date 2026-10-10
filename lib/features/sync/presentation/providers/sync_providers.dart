import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../data/datasources/desktop_oauth_service.dart';
import '../../data/datasources/mock_supabase_sync_client.dart';
import '../../data/datasources/supabase_sync_client.dart';
import '../../data/repositories/outbox_repository_impl.dart';
import '../../data/repositories/remote_sync_repository_impl.dart';
import '../../domain/entities/sync_state.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../../domain/repositories/remote_sync_repository.dart';
import '../../domain/services/external_calendar_relay.dart';
import '../../domain/services/idempotent_sync_engine.dart';
import '../../domain/services/lww_conflict_resolver.dart';
import '../../application/sync_coordinator.dart';

final mockSupabaseClientProvider = Provider<MockSupabaseSyncClient>((ref) {
  return MockSupabaseSyncClient();
});

final supabaseClientProvider = Provider<SupabaseSyncClient>((ref) {
  return ref.watch(mockSupabaseClientProvider);
});

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OutboxRepositoryImpl(db);
});

final remoteSyncRepositoryProvider = Provider<RemoteSyncRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RemoteSyncRepositoryImpl(client);
});

final lwwConflictResolverProvider = Provider<LwwConflictResolver>((ref) {
  return const LwwConflictResolver();
});

final idempotentSyncEngineProvider = Provider<IdempotentSyncEngine>((ref) {
  final outboxRepo = ref.watch(outboxRepositoryProvider);
  final remoteRepo = ref.watch(remoteSyncRepositoryProvider);
  return IdempotentSyncEngine(
    outboxRepo: outboxRepo,
    remoteRepo: remoteRepo,
    deviceId: 'device-local-main',
  );
});

final syncCoordinatorProvider =
    StateNotifierProvider<SyncCoordinator, SyncState>((ref) {
  final outboxRepo = ref.watch(outboxRepositoryProvider);
  final remoteRepo = ref.watch(remoteSyncRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  final syncEngine = ref.watch(idempotentSyncEngineProvider);
  final resolver = ref.watch(lwwConflictResolverProvider);

  return SyncCoordinator(
    outboxRepo: outboxRepo,
    remoteRepo: remoteRepo,
    db: db,
    syncEngine: syncEngine,
    clientId: 'device-local-main',
    conflictResolver: resolver,
  );
});


final pendingOutboxCountStreamProvider = StreamProvider<int>((ref) {
  final outboxRepo = ref.watch(outboxRepositoryProvider);
  return outboxRepo.watchPendingCount();
});

final desktopOAuthServiceProvider = Provider<DesktopOAuthService>((ref) {
  return MockDesktopOAuthService();
});

final externalCalendarRelayProvider = Provider<ExternalCalendarRelayService>((ref) {
  return MockExternalCalendarRelayService();
});
