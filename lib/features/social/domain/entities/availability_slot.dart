import 'package:flutter/material.dart';

@immutable
class AvailabilitySlot {
  final DateTime startTime;
  final DateTime endTime;
  final int totalMembers;
  final int busyCount;
  final List<String> busyMemberIds;
  final List<String> freeMemberIds;

  const AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.totalMembers,
    required this.busyCount,
    this.busyMemberIds = const [],
    this.freeMemberIds = const [],
  });

  int get freeCount => totalMembers - busyCount;
  double get busyDensity => totalMembers > 0 ? (busyCount / totalMembers).clamp(0.0, 1.0) : 0.0;
  double get freeRatio => totalMembers > 0 ? (freeCount / totalMembers).clamp(0.0, 1.0) : 1.0;
  bool get isZeroConflict => busyCount == 0;
  bool get isFullyBooked => totalMembers > 0 && busyCount >= totalMembers;

  Color get color {
    if (totalMembers == 0 || isZeroConflict) {
      // Emerald soft glow for 100% free / optimal slot
      return const Color(0xFF10B981).withValues(alpha: 0.18);
    } else if (isFullyBooked) {
      // Crimson red for fully booked collision
      return const Color(0xFFEF4444).withValues(alpha: 0.40);
    } else {
      // Amber interpolated for partial conflicts
      final density = busyDensity;
      final alpha = (0.15 + (0.35 * density)).clamp(0.15, 0.50);
      return const Color(0xFFF59E0B).withValues(alpha: alpha);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilitySlot &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          totalMembers == other.totalMembers &&
          busyCount == other.busyCount;

  @override
  int get hashCode => Object.hash(startTime, endTime, totalMembers, busyCount);
}
