import 'dart:async';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/user_device.dart';
import 'auth_remote_datasource.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  final Map<String, _MockUserEntry> _usersByEmail = {};
  final Map<String, _MockUserEntry> _usersById = {};
  final Map<String, String> _magicTokensByEmail = {}; // email -> token
  final Map<String, List<UserDevice>> _devicesByUserId = {};

  MockAuthRemoteDataSource() {
    // Seed default test user
    const defaultId = 'user-test-default-id';
    final defaultEntry = _MockUserEntry(
      id: defaultId,
      email: 'test@chronohub.com',
      password: 'password123',
      displayName: 'Test User',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    );
    _usersByEmail[defaultEntry.email] = defaultEntry;
    _usersById[defaultEntry.id] = defaultEntry;
  }

  void reset() {
    _usersByEmail.clear();
    _usersById.clear();
    _magicTokensByEmail.clear();
    _devicesByUserId.clear();
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    var entry = _usersByEmail[key];
    if (entry == null) {
      final id = 'user-${key.replaceAll('@', '_').replaceAll('.', '_')}';
      entry = _MockUserEntry(
        id: id,
        email: key,
        password: password,
        displayName: key.split('@').first,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      _usersByEmail[key] = entry;
      _usersById[id] = entry;
    } else if (entry.password != password) {
      throw const AuthFailure('Invalid email or password.');
    }

    final user = AuthUser.authenticated(
      id: entry.id,
      email: entry.email,
      displayName: entry.displayName,
      createdAt: entry.createdAt,
      lastSignInAt: DateTime.now(),
    );

    return AuthSession(
      accessToken: 'mock_jwt_access_${UuidUtils.generate()}',
      refreshToken: 'mock_jwt_refresh_${UuidUtils.generate()}',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: user,
    );
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_usersByEmail.containsKey(normalized)) {
      throw const AuthFailure('User already registered with this email.');
    }

    final userId = 'user_${UuidUtils.generate().substring(0, 8)}';
    final entry = _MockUserEntry(
      id: userId,
      email: normalized,
      password: password,
      displayName: displayName ?? normalized.split('@').first,
      createdAt: DateTime.now(),
    );

    _usersByEmail[normalized] = entry;
    _usersById[userId] = entry;

    final user = AuthUser.authenticated(
      id: entry.id,
      email: entry.email,
      displayName: entry.displayName,
      createdAt: entry.createdAt,
      lastSignInAt: DateTime.now(),
    );

    return AuthSession(
      accessToken: 'mock_jwt_access_${UuidUtils.generate()}',
      refreshToken: 'mock_jwt_refresh_${UuidUtils.generate()}',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: user,
    );
  }

  @override
  Future<void> sendMagicLink({required String email, String? redirectUrl}) async {
    final normalized = email.trim().toLowerCase();
    const otp = '123456';
    _magicTokensByEmail[normalized] = otp;
  }

  @override
  Future<AuthSession> verifyMagicLink({required Uri uri}) async {
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];

    if (token == null || email == null) {
      throw const AuthFailure('Invalid magic link callback parameters.');
    }

    return verifyOtp(email: email, token: token);
  }

  @override
  Future<AuthSession> verifyOtp({
    required String email,
    required String token,
    String type = 'magiclink',
  }) async {
    final normalized = email.trim().toLowerCase();
    final expectedToken = _magicTokensByEmail[normalized];

    // Accept expected token or default '123456' in tests
    if (token != expectedToken && token != '123456') {
      throw const AuthFailure('Invalid or expired OTP token.');
    }

    _magicTokensByEmail.remove(normalized);

    var entry = _usersByEmail[normalized];
    if (entry == null) {
      // Auto-create user on magic link if doesn't exist
      final userId = 'user_${UuidUtils.generate().substring(0, 8)}';
      entry = _MockUserEntry(
        id: userId,
        email: normalized,
        password: '',
        displayName: normalized.split('@').first,
        createdAt: DateTime.now(),
      );
      _usersByEmail[normalized] = entry;
      _usersById[userId] = entry;
    }

    final user = AuthUser.authenticated(
      id: entry.id,
      email: entry.email,
      displayName: entry.displayName,
      createdAt: entry.createdAt,
      lastSignInAt: DateTime.now(),
    );

    return AuthSession(
      accessToken: 'mock_jwt_access_${UuidUtils.generate()}',
      refreshToken: 'mock_jwt_refresh_${UuidUtils.generate()}',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: user,
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (!_usersByEmail.containsKey(normalized)) {
      throw const AuthFailure('Email address not found.');
    }
  }

  @override
  Future<AuthSession> refreshSession({required String refreshToken}) async {
    if (refreshToken.isEmpty) {
      throw const AuthFailure('Invalid refresh token.');
    }
    // Return simulated refreshed tokens
    final user = AuthUser.authenticated(
      id: 'refreshed-user-id',
      email: 'refreshed@chronohub.com',
      createdAt: DateTime.now(),
    );
    return AuthSession(
      accessToken: 'mock_jwt_access_refreshed_${UuidUtils.generate()}',
      refreshToken: 'mock_jwt_refresh_refreshed_${UuidUtils.generate()}',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: user,
    );
  }

  @override
  Future<void> signOut() async {
    // In-memory mock sign out is a no-op
  }

  @override
  Future<List<UserDevice>> fetchDevices(String userId) async {
    return List<UserDevice>.unmodifiable(_devicesByUserId[userId] ?? []);
  }

  @override
  Future<void> upsertDevice(UserDevice device) async {
    final list = _devicesByUserId.putIfAbsent(device.userId, () => []);
    list.removeWhere((d) => d.id == device.id);
    list.add(device);
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    for (final list in _devicesByUserId.values) {
      list.removeWhere((d) => d.id == deviceId);
    }
  }
}

class _MockUserEntry {
  final String id;
  final String email;
  final String password;
  final String displayName;
  final DateTime createdAt;

  _MockUserEntry({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    required this.createdAt,
  });
}
