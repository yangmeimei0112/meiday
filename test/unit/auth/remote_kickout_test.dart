import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/core/utils/hash_utils.dart';
import 'package:smart_calendar_hub/features/auth/data/datasources/mock_session_realtime_datasource.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_state.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/kickout_event.dart';
import 'package:smart_calendar_hub/features/auth/presentation/providers/auth_providers.dart';

void main() {
  group('Feature #13: Remote Session Kickout Tests', () {
    late ProviderContainer container;
    late InMemoryDatabaseConnectionFactory inMemoryDbFactory;
    late InMemorySecureStorageService inMemoryStorage;
    late MockSessionRealtimeDataSource mockRealtime;

    setUp(() {
      inMemoryDbFactory = InMemoryDatabaseConnectionFactory();
      inMemoryStorage = InMemorySecureStorageService();
      mockRealtime = MockSessionRealtimeDataSource();

      container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorage),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      mockRealtime.dispose();
    });

    test('Receiving remote kickout event immediately severs user database and reverts to guest mode', () async {
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.init();

      // Sign in as user
      await notifier.signInWithEmail('test@chronohub.com', 'password123');
      final authState = container.read(authNotifierProvider);
      expect(authState, isA<Authenticated>());
      final authedUser = (authState as Authenticated).user;

      // Verify connected to user DB
      expect(container.read(currentAuthForDbProvider), isA<AuthenticatedDbAuthState>());
      expect(
        HashUtils.resolveDatabaseName(container.read(currentAuthForDbProvider).userId),
        startsWith('user_'),
      );

      final myDeviceId = await container.read(sessionRegistryRepositoryProvider).getCurrentDeviceId();

      // Simulate remote kick broadcast targeted at this device
      mockRealtime.simulateRemoteKick(
        KickoutEvent(
          userId: authedUser.id,
          targetDeviceId: myDeviceId,
          reason: 'Terminated from Windows Desktop',
          timestamp: DateTime.now(),
        ),
      );

      // Allow microtask stream event dispatch
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert state transition to AuthUnauthenticated
      final postKickState = container.read(authNotifierProvider);
      expect(postKickState, isA<AuthUnauthenticated>());
      expect((postKickState as AuthUnauthenticated).reason, equals('Terminated from Windows Desktop'));

      // Assert database switched back to guest.db
      final finalDbState = container.read(currentAuthForDbProvider);
      expect(finalDbState, isA<GuestDbAuthState>());
      expect(HashUtils.resolveDatabaseName(finalDbState.userId), equals('guest.db'));

      // Assert secure tokens wiped
      expect(inMemoryStorage.entryCount, equals(1)); // only deviceId remains, session token cleared
    });
  });
}
