import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/connection/database_lifecycle_coordinator.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/mock_auth_remote_datasource.dart';
import '../../data/datasources/mock_session_realtime_datasource.dart';
import '../../data/datasources/session_realtime_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/session_registry_repository_impl.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_device.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/session_registry_repository.dart';
import '../controllers/auth_notifier.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthLocalDataSource(storage);
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return MockAuthRemoteDataSource();
});

final sessionRealtimeDataSourceProvider = Provider<SessionRealtimeDataSource>((ref) {
  return MockSessionRealtimeDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

final sessionRegistryRepositoryProvider = Provider<SessionRegistryRepository>((ref) {
  final lifecycle = ref.watch(databaseLifecycleCoordinatorProvider);
  return SessionRegistryRepositoryImpl(
    deviceDaoProvider: () => lifecycle.activeDatabase.userDeviceDao,
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    realtimeDataSource: ref.watch(sessionRealtimeDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final sessionRegistry = ref.watch(sessionRegistryRepositoryProvider);
  final lifecycle = ref.watch(databaseLifecycleCoordinatorProvider);
  return AuthNotifier(
    ref: ref,
    authRepo: authRepo,
    sessionRegistry: sessionRegistry,
    lifecycleCoordinator: lifecycle,
  );
});

final activeDevicesStreamProvider = StreamProvider.autoDispose<List<UserDevice>>((ref) {
  final authState = ref.watch(authNotifierProvider);
  if (authState is Authenticated) {
    final sessionRegistry = ref.watch(sessionRegistryRepositoryProvider);
    return sessionRegistry.watchActiveDevices(userId: authState.user.id);
  }
  return const Stream.empty();
});

final currentDeviceIdProvider = FutureProvider.autoDispose<String>((ref) {
  final sessionRegistry = ref.watch(sessionRegistryRepositoryProvider);
  return sessionRegistry.getCurrentDeviceId();
});
