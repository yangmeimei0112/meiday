import 'package:flutter/foundation.dart';

@immutable
class OptimalMeetingSlot {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int maxConflictCount;
  final int totalConflictWeight;
  final List<String> conflictedMemberIds;
  final List<String> availableMemberIds;
  final double score;

  const OptimalMeetingSlot({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.maxConflictCount,
    required this.totalConflictWeight,
    this.conflictedMemberIds = const [],
    this.availableMemberIds = const [],
    required this.score,
  });

  bool get isZeroConflict => maxConflictCount == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OptimalMeetingSlot &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          durationMinutes == other.durationMinutes &&
          maxConflictCount == other.maxConflictCount;

  @override
  int get hashCode => Object.hash(startTime, endTime, durationMinutes, maxConflictCount);
}
