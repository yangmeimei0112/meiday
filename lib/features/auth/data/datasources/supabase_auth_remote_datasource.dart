import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_session.dart' as domain;
import '../../domain/entities/auth_user.dart' as domain;
import '../../domain/entities/user_device.dart';
import '../models/user_device_model.dart';
import 'auth_remote_datasource.dart';

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  final SupabaseClient _client;

  SupabaseAuthRemoteDataSource([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<domain.AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _mapSession(response.session!, response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Sign in failed: $e', cause: e);
    }
  }

  @override
  Future<domain.AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      if (response.session == null) {
        throw const AuthFailure('Registration succeeded. Please confirm your email.');
      }
      return _mapSession(response.session!, response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Sign up failed: $e', cause: e);
    }
  }

  @override
  Future<void> sendMagicLink({required String email, String? redirectUrl}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectUrl,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Sending magic link failed: $e', cause: e);
    }
  }

  @override
  Future<domain.AuthSession> verifyMagicLink({required Uri uri}) async {
    try {
      final response = await _client.auth.getSessionFromUrl(uri);
      return _mapSession(response.session, response.session.user);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Verifying magic link failed: $e', cause: e);
    }
  }

  @override
  Future<domain.AuthSession> verifyOtp({
    required String email,
    required String token,
    String type = 'magiclink',
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );
      return _mapSession(response.session!, response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Verifying OTP failed: $e', cause: e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Password reset request failed: $e', cause: e);
    }
  }

  @override
  Future<domain.AuthSession> refreshSession({required String refreshToken}) async {
    try {
      final response = await _client.auth.refreshSession(refreshToken);
      return _mapSession(response.session!, response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, cause: e);
    } catch (e) {
      throw AuthFailure('Refreshing session failed: $e', cause: e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<List<UserDevice>> fetchDevices(String userId) async {
    try {
      final rows = await _client
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .order('last_active_at', ascending: false);
      return (rows as List<dynamic>)
          .map((r) => UserDeviceModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> upsertDevice(UserDevice device) async {
    try {
      await _client.from('user_devices').upsert(UserDeviceModel.toJson(device));
    } catch (_) {}
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    try {
      await _client.from('user_devices').delete().eq('id', deviceId);
    } catch (_) {}
  }

  domain.AuthSession _mapSession(Session session, User user) {
    final expiresAt = session.expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
        : DateTime.now().add(const Duration(hours: 1));

    return domain.AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      expiresAt: expiresAt,
      tokenType: session.tokenType,
      user: domain.AuthUser.authenticated(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
        createdAt: DateTime.parse(user.createdAt),
        lastSignInAt: user.lastSignInAt != null ? DateTime.parse(user.lastSignInAt!) : null,
      ),
    );
  }
}
