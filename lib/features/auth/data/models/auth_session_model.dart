import '../../domain/entities/auth_session.dart';
import 'auth_user_model.dart';

class AuthSessionModel {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final AuthUserModel user;

  const AuthSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'bearer',
    required this.user,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }

  AuthSession toDomain() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
      user: user.toDomain(),
    );
  }

  factory AuthSessionModel.fromDomain(AuthSession session) {
    return AuthSessionModel(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
      tokenType: session.tokenType,
      user: AuthUserModel.fromDomain(session.user),
    );
  }
}
