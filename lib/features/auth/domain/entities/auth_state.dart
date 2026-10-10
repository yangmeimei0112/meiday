import 'package:meta/meta.dart';
import '../../../../core/errors/failures.dart';
import 'auth_user.dart';
import 'auth_session.dart';

@immutable
sealed class AuthState {
  const AuthState();

  bool get isGuest => this is AuthGuest;

  AuthUser? get currentUser {
    final s = this;
    if (s is Authenticated) return s.user;
    if (s is AuthGuest) return s.guestUser;
    if (s is AuthMigrationRequired) return s.user;
    return null;
  }
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  final String? message;
  const AuthLoading({this.message});
}

final class AuthGuest extends AuthState {
  final AuthUser guestUser;
  const AuthGuest(this.guestUser);
}

final class Authenticated extends AuthState {
  final AuthUser user;
  final AuthSession session;
  const Authenticated({required this.user, required this.session});
}

final class AuthUnauthenticated extends AuthState {
  final String? reason;
  const AuthUnauthenticated({this.reason});
}

final class AuthError extends AuthState {
  final AuthFailure failure;
  const AuthError(this.failure);
}

final class AuthMigrationRequired extends AuthState {
  final AuthUser user;
  final AuthSession session;
  final int localGuestEventCount;
  final int cloudEventCount;

  const AuthMigrationRequired({
    required this.user,
    required this.session,
    required this.localGuestEventCount,
    required this.cloudEventCount,
  });
}
