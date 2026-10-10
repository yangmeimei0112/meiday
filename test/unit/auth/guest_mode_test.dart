import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/database_lifecycle_coordinator.dart';
import 'package:smart_calendar_hub/core/database/migrations/guest_migration_executor.dart';
import 'package:smart_calendar_hub/core/database/migrations/migration_models.dart';
import 'package:smart_calendar_hub/core/errors/failures.dart';
import 'package:smart_calendar_hub/core/utils/hash_utils.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_session.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_state.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_user.dart';
import 'package:smart_calendar_hub/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:smart_calendar_hub/features/auth/presentation/providers/auth_providers.dart';

class FailingGuestMigrationExecutor extends GuestMigrationExecutor {
  @override
  Future<MigrationResult> migrate({
    required AppDatabase guestDb,
    required AppDatabase userDb,
    required String userId,
    required MigrationMode mode,
  }) async {
    throw const DatabaseFailure('Simulated SQLite disk corruption error');
  }
}

void main() {
  group('Feature #4: Zero-Friction Guest Mode & Transition Tests', () {
    late ProviderContainer container;
    late InMemoryDatabaseConnectionFactory inMemoryDbFactory;
    late InMemorySecureStorageService inMemoryStorage;

    setUp(() {
      inMemoryDbFactory = InMemoryDatabaseConnectionFactory();
      inMemoryStorage = InMemorySecureStorageService();
      container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial application state starts in AuthGuest without login prompt', () async {
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.init();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthGuest>());
      final guestState = state as AuthGuest;
      expect(guestState.guestUser.isGuest, isTrue);

      final dbState = container.read(currentAuthForDbProvider);
      expect(dbState, isA<GuestDbAuthState>());
      expect(HashUtils.resolveDatabaseName(dbState.userId), equals('guest.db'));
    });

    test('Sign out switches active database back to guest mode cleanly', () async {
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.init();

      // Sign in as authenticated user
      await notifier.signInWithEmail('test@chronohub.com', 'password123');
      final authState = container.read(authNotifierProvider);
      expect(authState, isA<Authenticated>());

      final userDbState = container.read(currentAuthForDbProvider);
      expect(userDbState, isA<AuthenticatedDbAuthState>());
      expect(HashUtils.resolveDatabaseName(userDbState.userId), startsWith('user_'));

      // Sign out
      await notifier.signOut();

      final postLogoutState = container.read(authNotifierProvider);
      expect(postLogoutState, isA<AuthGuest>());

      final finalDbState = container.read(currentAuthForDbProvider);
      expect(finalDbState, isA<GuestDbAuthState>());
      expect(HashUtils.resolveDatabaseName(finalDbState.userId), equals('guest.db'));
    });

    test('Continue as guest resets any active session and sets state to AuthGuest', () async {
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.init();

      await notifier.continueAsGuest();
      expect(container.read(authNotifierProvider), isA<AuthGuest>());
    });

    test('Migration failure in _handlePostAuthentication emits AuthError', () async {
      final failingContainer = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorage),
          authNotifierProvider.overrideWith((ref) => AuthNotifier(
                ref: ref,
                authRepo: ref.watch(authRepositoryProvider),
                sessionRegistry: ref.watch(sessionRegistryRepositoryProvider),
                lifecycleCoordinator: ref.watch(databaseLifecycleCoordinatorProvider),
                migrationExecutor: FailingGuestMigrationExecutor(),
              )),
        ],
      );
      addTearDown(failingContainer.dispose);

      final failingGuestDb = failingContainer.read(databaseLifecycleCoordinatorProvider).activeDatabase;
      await failingGuestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-guest-fail',
          userId: 'guest',
          title: 'Guest Event',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final notifier = failingContainer.read(authNotifierProvider.notifier);
      await notifier.init();

      // Trigger sign-in with new account scenario
      await notifier.signUpWithEmail('fail@example.com', 'pass123', displayName: 'Fail User');

      final authState = failingContainer.read(authNotifierProvider);
      expect(authState, isA<AuthError>());
      final errorState = authState as AuthError;
      expect(errorState.failure.message, contains('Guest migration failed:'));
    });

    test('Migration failure in resolveMigrationConflict emits AuthError', () async {
      final failingContainer = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorage),
          authNotifierProvider.overrideWith((ref) => AuthNotifier(
                ref: ref,
                authRepo: ref.watch(authRepositoryProvider),
                sessionRegistry: ref.watch(sessionRegistryRepositoryProvider),
                lifecycleCoordinator: ref.watch(databaseLifecycleCoordinatorProvider),
                migrationExecutor: FailingGuestMigrationExecutor(),
              )),
        ],
      );
      addTearDown(failingContainer.dispose);

      final notifier = failingContainer.read(authNotifierProvider.notifier);
      await notifier.init();

      // Set state to AuthMigrationRequired
      final dummySession = AuthSession(
        accessToken: 'tok',
        refreshToken: 'ref',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: AuthUser.authenticated(
          id: 'u-conflict-fail',
          email: 'conflict@example.com',
          displayName: 'Conflict User',
          createdAt: DateTime.now(),
        ),
      );
      notifier.state = AuthMigrationRequired(
        user: dummySession.user,
        session: dummySession,
        localGuestEventCount: 2,
        cloudEventCount: 3,
      );

      await notifier.resolveMigrationConflict(MigrationMode.mergeLocal);

      final authState = failingContainer.read(authNotifierProvider);
      expect(authState, isA<AuthError>());
      final errorState = authState as AuthError;
      expect(errorState.failure.message, contains('Guest migration failed:'));
    });
  });
}
