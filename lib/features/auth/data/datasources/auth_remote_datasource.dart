import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_device.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSession> signInWithEmail({required String email, required String password});
  Future<AuthSession> signUpWithEmail({required String email, required String password, String? displayName});
  Future<void> sendMagicLink({required String email, String? redirectUrl});
  Future<AuthSession> verifyMagicLink({required Uri uri});
  Future<AuthSession> verifyOtp({required String email, required String token, String type = 'magiclink'});
  Future<void> sendPasswordResetEmail({required String email});
  Future<AuthSession> refreshSession({required String refreshToken});
  Future<void> signOut();
  Future<List<UserDevice>> fetchDevices(String userId);
  Future<void> upsertDevice(UserDevice device);
  Future<void> removeDevice(String deviceId);
}
