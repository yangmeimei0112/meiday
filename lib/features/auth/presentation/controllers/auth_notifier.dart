import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/database/connection/database_lifecycle_coordinator.dart';
import '../../../../core/database/migrations/guest_migration_executor.dart';
import '../../../../core/database/migrations/migration_models.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/kickout_event.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/session_registry_repository.dart';
import '../../../../app/router.dart';
import '../../services/migration_conflict_detector.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthRepository _authRepo;
  final SessionRegistryRepository _sessionRegistry;
  final DatabaseLifecycleCoordinator _lifecycleCoordinator;
  final GuestMigrationExecutor _migrationExecutor;
  StreamSubscription<KickoutEvent>? _kickoutSub;

  AuthNotifier({
    required Ref ref,
    required AuthRepository authRepo,
    required SessionRegistryRepository sessionRegistry,
    required DatabaseLifecycleCoordinator lifecycleCoordinator,
    GuestMigrationExecutor? migrationExecutor,
  })  : _ref = ref,
        _authRepo = authRepo,
        _sessionRegistry = sessionRegistry,
        _lifecycleCoordinator = lifecycleCoordinator,
        _migrationExecutor = migrationExecutor ?? GuestMigrationExecutor(),
        super(const AuthInitial()) {
    authRouterNotifier.updateState(state);
    init();
  }

  @override
  set state(AuthState value) {
    super.state = value;
    authRouterNotifier.updateState(value);
  }

  Future<void> init() async {
    state = const AuthLoading(message: 'Initializing session...');
    try {
      final initial = await _authRepo.getInitialAuthState();
      await _transitionTo(initial);
    } catch (_) {
      await _transitionTo(AuthGuest(AuthUser.guest()));
    }
  }

  Future<void> _transitionTo(AuthState newState) async {
    state = newState;
    if (newState is Authenticated) {
      // 1. Safely switch active SQLite database to user_{sha256(uid)}.db
      await _lifecycleCoordinator.switchSession(AuthenticatedDbAuthState(newState.user.id));

      // 2. Register current device in user_devices table
      await _sessionRegistry.registerCurrentDevice(userId: newState.user.id);

      // 3. Listen to remote kickout events
      _listenToKickout(newState.user.id);
    } else if (newState is AuthGuest || newState is AuthUnauthenticated) {
      // Sever active SQLite database and return to guest.db
      await _lifecycleCoordinator.severAndSwitchToGuest();
      _cancelKickoutListener();
    }
  }

  void _listenToKickout(String userId) {
    _cancelKickoutListener();
    _kickoutSub = _sessionRegistry.watchRemoteKickout(userId: userId).listen((event) async {
      final myDeviceId = await _sessionRegistry.getCurrentDeviceId();
      if (event.matchesDevice(myDeviceId)) {
        await handleRemoteKickout(event.reason);
      }
    });
  }

  void _cancelKickoutListener() {
    _kickoutSub?.cancel();
    _kickoutSub = null;
  }

  Future<void> handleRemoteKickout(String reason) async {
    _cancelKickoutListener();
    await _authRepo.signOut();
    await _transitionTo(AuthUnauthenticated(reason: reason));
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthLoading(message: 'Signing in...');
    try {
      final session = await _authRepo.signInWithEmail(email: email, password: password);
      await _handlePostAuthentication(session, isNewRegistration: false);
    } on AuthFailure catch (f) {
      state = AuthError(f);
    } catch (e) {
      state = AuthError(AuthFailure('Sign in failed: $e', cause: e));
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    state = const AuthLoading(message: 'Creating account...');
    try {
      final session = await _authRepo.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _handlePostAuthentication(session, isNewRegistration: true);
    } on AuthFailure catch (f) {
      state = AuthError(f);
    } catch (e) {
      state = AuthError(AuthFailure('Sign up failed: $e', cause: e));
    }
  }

  Future<void> sendMagicLink(String email) async {
    state = const AuthLoading(message: 'Sending magic link...');
    try {
      await _authRepo.sendMagicLink(email: email);
      // Keep state as unauthenticated or initial so UI can navigate to sent screen
      state = const AuthInitial();
    } on AuthFailure catch (f) {
      state = AuthError(f);
    } catch (e) {
      state = AuthError(AuthFailure('Failed to send magic link: $e', cause: e));
    }
  }

  Future<void> verifyMagicLink(Uri uri) async {
    state = const AuthLoading(message: 'Verifying link...');
    try {
      final session = await _authRepo.verifyMagicLink(uri: uri);
      await _handlePostAuthentication(session, isNewRegistration: false);
    } on AuthFailure catch (f) {
      state = AuthError(f);
    } catch (e) {
      state = AuthError(AuthFailure('Failed to verify magic link: $e', cause: e));
    }
  }

  Future<void> verifyOtp(String email, String token) async {
    state = const AuthLoading(message: 'Verifying code...');
    try {
      final session = await _authRepo.verifyOtp(email: email, token: token);
      await _handlePostAuthentication(session, isNewRegistration: false);
    } on AuthFailure catch (f) {
      state = AuthError(f);
    } catch (e) {
      state = AuthError(AuthFailure('Failed to verify OTP: $e', cause: e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AuthLoading(message: 'Sending password reset email...');
    try {
      await _authRepo.sendPasswordResetEmail(email: email);
      state = const AuthInitial();
    } on AuthFailure catch (f) {
      state = AuthError(f);
    } catch (e) {
      state = AuthError(AuthFailure('Failed to send reset email: $e', cause: e));
    }
  }

  Future<void> _handlePostAuthentication(
    AuthSession session, {
    required bool isNewRegistration,
  }) async {
    // Check if guestDb has data that needs migration
    final guestDb = _lifecycleCoordinator.activeDatabase;
    final connFactory = _ref.read(databaseConnectionFactoryProvider);
    final userDbName = resolveDatabaseName(session.user.id);
    final userDb = AppDatabase(connFactory.createConnection(userDbName));

    try {
      final scenario = await MigrationConflictDetector.detectScenario(
        guestDb: guestDb,
        userDb: userDb,
        isNewRegistration: isNewRegistration,
      );

      if (scenario == MigrationScenario.noGuestData) {
        await userDb.close();
        await _transitionTo(Authenticated(user: session.user, session: session));
      } else if (scenario == MigrationScenario.brandNewAccount) {
        // Auto-migrate guest data to brand-new userDb
        await _migrationExecutor.migrate(
          guestDb: guestDb,
          userDb: userDb,
          userId: session.user.id,
          mode: MigrationMode.autoMigrate,
        );
        await userDb.close();
        await _transitionTo(Authenticated(user: session.user, session: session));
      } else {
        // Existing account conflict -> Emit AuthMigrationRequired so UI prompts conflict dialog
        final guestEvents = await guestDb.select(guestDb.calendarEvents).get();
        final userEvents = await userDb.select(userDb.calendarEvents).get();
        await userDb.close();

        state = AuthMigrationRequired(
          user: session.user,
          session: session,
          localGuestEventCount: guestEvents.length,
          cloudEventCount: userEvents.length,
        );
      }
    } catch (e) {
      await userDb.close();
      state = AuthError(AuthFailure('Guest migration failed: $e', cause: e));
    }
  }

  Future<void> resolveMigrationConflict(MigrationMode mode) async {
    final currentState = state;
    if (currentState is! AuthMigrationRequired) return;

    state = const AuthLoading(message: 'Migrating data...');
    final guestDb = _lifecycleCoordinator.activeDatabase;
    final connFactory = _ref.read(databaseConnectionFactoryProvider);
    final userDbName = resolveDatabaseName(currentState.user.id);
    final userDb = AppDatabase(connFactory.createConnection(userDbName));

    try {
      await _migrationExecutor.migrate(
        guestDb: guestDb,
        userDb: userDb,
        userId: currentState.user.id,
        mode: mode,
      );
      await _transitionTo(Authenticated(user: currentState.user, session: currentState.session));
    } catch (e) {
      state = AuthError(AuthFailure('Guest migration failed: $e', cause: e));
    } finally {
      await userDb.close();
    }
  }

  Future<void> signOut() async {
    state = const AuthLoading(message: 'Signing out...');
    _cancelKickoutListener();
    await _authRepo.signOut();
    await _transitionTo(AuthGuest(AuthUser.guest()));
  }

  Future<void> continueAsGuest() async {
    _cancelKickoutListener();
    await _authRepo.continueAsGuest();
    await _transitionTo(AuthGuest(AuthUser.guest()));
  }

  @override
  void dispose() {
    _cancelKickoutListener();
    super.dispose();
  }
}
