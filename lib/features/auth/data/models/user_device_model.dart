import '../../../../core/database/app_database.dart';
import '../../domain/entities/user_device.dart';

class UserDeviceModel {
  static UserDevice fromData(UserDeviceData data) {
    return UserDevice(
      id: data.id,
      userId: data.userId,
      deviceName: data.deviceName,
      platform: data.platform,
      deviceToken: data.deviceToken,
      lastActiveAt: data.lastActiveAt,
      clientIp: data.clientIp,
      isCurrent: data.isCurrent,
      createdAt: data.createdAt,
    );
  }

  static UserDevice fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceName: json['device_name'] as String,
      platform: json['platform'] as String,
      deviceToken: json['device_token'] as String? ?? '',
      lastActiveAt: DateTime.parse(json['last_active_at'] as String),
      clientIp: json['client_ip'] as String?,
      isCurrent: json['is_current'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toJson(UserDevice device) {
    return {
      'id': device.id,
      'user_id': device.userId,
      'device_name': device.deviceName,
      'platform': device.platform,
      'device_token': device.deviceToken,
      'last_active_at': device.lastActiveAt.toIso8601String(),
      'client_ip': device.clientIp,
      'is_current': device.isCurrent,
      'created_at': device.createdAt.toIso8601String(),
    };
  }
}
