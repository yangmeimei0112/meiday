import 'package:meta/meta.dart';

@immutable
class UserDevice {
  final String id;
  final String userId;
  final String deviceName;
  final String platform; // 'windows', 'macos', 'ios', 'android', 'web'
  final String deviceToken;
  final DateTime lastActiveAt;
  final String? clientIp;
  final bool isCurrent;
  final DateTime createdAt;

  const UserDevice({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platform,
    required this.deviceToken,
    required this.lastActiveAt,
    this.clientIp,
    required this.isCurrent,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          isCurrent == other.isCurrent;

  @override
  int get hashCode => Object.hash(id, userId, isCurrent);
}
