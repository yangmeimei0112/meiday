import 'package:meta/meta.dart';
import 'auth_user.dart';

@immutable
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'bearer',
    required this.user,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Triggers proactive token refresh when active and less than 5 minutes remain
  bool get needsRefresh => !isExpired && expiresAt.difference(DateTime.now()).inMinutes <= 5;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresAt == other.expiresAt &&
          user == other.user;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, expiresAt, user);
}
