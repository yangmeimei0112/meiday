import '../entities/auth_session.dart';
import '../entities/auth_state.dart';

abstract class AuthRepository {
  Future<AuthState> getInitialAuthState();
  Stream<AuthState> watchAuthState();
  Future<AuthSession> signInWithEmail({required String email, required String password});
  Future<AuthSession> signUpWithEmail({required String email, required String password, String? displayName});
  Future<void> sendMagicLink({required String email, String? redirectUrl});
  Future<AuthSession> verifyMagicLink({required Uri uri});
  Future<AuthSession> verifyOtp({required String email, required String token, String type = 'magiclink'});
  Future<void> sendPasswordResetEmail({required String email});
  Future<AuthSession> refreshSession();
  Future<void> signOut();
  Future<void> continueAsGuest();
}
