import 'dart:async';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Stream<AuthState> watchAuthState() => _authStateController.stream;

  @override
  Future<AuthState> getInitialAuthState() async {
    try {
      final session = await _localDataSource.getSession();
      if (session == null) {
        final guestState = AuthGuest(AuthUser.guest());
        _authStateController.add(guestState);
        return guestState;
      }

      if (session.isExpired) {
        await _localDataSource.clearSession();
        final guestState = AuthGuest(AuthUser.guest());
        _authStateController.add(guestState);
        return guestState;
      }

      // Proactive refresh if expiration is near
      AuthSession activeSession = session;
      if (session.needsRefresh) {
        try {
          activeSession = await _remoteDataSource.refreshSession(refreshToken: session.refreshToken);
          await _localDataSource.saveSession(activeSession);
        } catch (_) {
          // If refresh fails but current token isn't expired yet, continue using current
        }
      }

      final authenticatedState = Authenticated(user: activeSession.user, session: activeSession);
      _authStateController.add(authenticatedState);
      return authenticatedState;
    } catch (_) {
      final guestState = AuthGuest(AuthUser.guest());
      _authStateController.add(guestState);
      return guestState;
    }
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final session = await _remoteDataSource.signInWithEmail(email: email, password: password);
    await _localDataSource.saveSession(session);
    _authStateController.add(Authenticated(user: session.user, session: session));
    return session;
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final session = await _remoteDataSource.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _localDataSource.saveSession(session);
    _authStateController.add(Authenticated(user: session.user, session: session));
    return session;
  }

  @override
  Future<void> sendMagicLink({required String email, String? redirectUrl}) {
    return _remoteDataSource.sendMagicLink(email: email, redirectUrl: redirectUrl);
  }

  @override
  Future<AuthSession> verifyMagicLink({required Uri uri}) async {
    final session = await _remoteDataSource.verifyMagicLink(uri: uri);
    await _localDataSource.saveSession(session);
    _authStateController.add(Authenticated(user: session.user, session: session));
    return session;
  }

  @override
  Future<AuthSession> verifyOtp({
    required String email,
    required String token,
    String type = 'magiclink',
  }) async {
    final session = await _remoteDataSource.verifyOtp(email: email, token: token, type: type);
    await _localDataSource.saveSession(session);
    _authStateController.add(Authenticated(user: session.user, session: session));
    return session;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _remoteDataSource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<AuthSession> refreshSession() async {
    final currentSession = await _localDataSource.getSession();
    if (currentSession == null) {
      throw const AuthFailure('No active session found to refresh.');
    }

    final refreshed = await _remoteDataSource.refreshSession(
      refreshToken: currentSession.refreshToken,
    );
    await _localDataSource.saveSession(refreshed);
    _authStateController.add(Authenticated(user: refreshed.user, session: refreshed));
    return refreshed;
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
    await _localDataSource.clearSession();
    _authStateController.add(AuthGuest(AuthUser.guest()));
  }

  @override
  Future<void> continueAsGuest() async {
    await _localDataSource.clearSession();
    _authStateController.add(AuthGuest(AuthUser.guest()));
  }

  void dispose() {
    _authStateController.close();
  }
}
