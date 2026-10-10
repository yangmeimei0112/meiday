import '../../domain/entities/auth_user.dart';

class AuthUserModel {
  final String id;
  final String? email;
  final String? displayName;
  final bool isGuest;
  final DateTime createdAt;
  final DateTime? lastSignInAt;

  const AuthUserModel({
    required this.id,
    this.email,
    this.displayName,
    required this.isGuest,
    required this.createdAt,
    this.lastSignInAt,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      isGuest: json['is_guest'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.parse(json['last_sign_in_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'is_guest': isGuest,
      'created_at': createdAt.toIso8601String(),
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
    };
  }

  AuthUser toDomain() {
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      isGuest: isGuest,
      createdAt: createdAt,
      lastSignInAt: lastSignInAt,
    );
  }

  factory AuthUserModel.fromDomain(AuthUser user) {
    return AuthUserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      isGuest: user.isGuest,
      createdAt: user.createdAt,
      lastSignInAt: user.lastSignInAt,
    );
  }
}
