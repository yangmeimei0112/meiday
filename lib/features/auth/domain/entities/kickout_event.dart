import 'package:meta/meta.dart';

@immutable
class KickoutEvent {
  final String userId;
  final String? targetDeviceId; // null means kick all devices except initiator
  final String? excludedDeviceId;
  final String reason;
  final DateTime timestamp;

  const KickoutEvent({
    required this.userId,
    this.targetDeviceId,
    this.excludedDeviceId,
    required this.reason,
    required this.timestamp,
  });

  bool matchesDevice(String deviceId) {
    if (targetDeviceId != null) {
      return targetDeviceId == deviceId;
    }
    if (excludedDeviceId != null) {
      return excludedDeviceId != deviceId;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KickoutEvent &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          targetDeviceId == other.targetDeviceId &&
          excludedDeviceId == other.excludedDeviceId &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(userId, targetDeviceId, excludedDeviceId, reason);
}
