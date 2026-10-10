import 'package:meta/meta.dart';

@immutable
class AuthUser {
  final String id;
  final String? email;
  final String? displayName;
  final bool isGuest;
  final DateTime createdAt;
  final DateTime? lastSignInAt;

  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    required this.isGuest,
    required this.createdAt,
    this.lastSignInAt,
  });

  factory AuthUser.guest({String? id, DateTime? createdAt}) {
    return AuthUser(
      id: id ?? 'guest',
      email: null,
      displayName: 'Guest User',
      isGuest: true,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory AuthUser.authenticated({
    required String id,
    required String email,
    String? displayName,
    required DateTime createdAt,
    DateTime? lastSignInAt,
  }) {
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName ?? email.split('@').first,
      isGuest: false,
      createdAt: createdAt,
      lastSignInAt: lastSignInAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          isGuest == other.isGuest;

  @override
  int get hashCode => Object.hash(id, email, isGuest);
}
