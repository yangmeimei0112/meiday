import 'dart:math';
import '../entities/availability_slot.dart';
import '../entities/optimal_meeting_slot.dart';

class OptimalMeetingFinder {
  List<OptimalMeetingSlot> findOptimalSlots({
    required List<AvailabilitySlot> availabilitySlots,
    required int durationMinutes,
    int slotIntervalMinutes = 30,
  }) {
    if (availabilitySlots.isEmpty || durationMinutes <= 0) {
      return const [];
    }

    final windowSize = (durationMinutes / slotIntervalMinutes).ceil();
    if (windowSize > availabilitySlots.length) {
      return const [];
    }

    final candidates = <OptimalMeetingSlot>[];

    for (int k = 0; k <= availabilitySlots.length - windowSize; k++) {
      final windowSlots = availabilitySlots.sublist(k, k + windowSize);
      final startTime = windowSlots.first.startTime;
      final candidateEndTime = startTime.add(Duration(minutes: durationMinutes));

      // Ensure meeting does not cross midnight into the next calendar day
      if (startTime.year != candidateEndTime.subtract(const Duration(milliseconds: 1)).year ||
          startTime.month != candidateEndTime.subtract(const Duration(milliseconds: 1)).month ||
          startTime.day != candidateEndTime.subtract(const Duration(milliseconds: 1)).day) {
        continue;
      }

      int maxConflict = 0;
      int totalConflictWeight = 0;
      final conflictedMembers = <String>{};
      final allFreeMembers = <String>{};

      for (int i = 0; i < windowSlots.length; i++) {
        final slot = windowSlots[i];
        maxConflict = max(maxConflict, slot.busyCount);
        totalConflictWeight += slot.busyCount;
        conflictedMembers.addAll(slot.busyMemberIds);
        if (i == 0) {
          allFreeMembers.addAll(slot.freeMemberIds);
        } else {
          allFreeMembers.retainAll(slot.freeMemberIds);
        }
      }

      // Compute heuristic score
      double score = 100.0 - (30.0 * maxConflict) - (10.0 * totalConflictWeight);

      // Prime business / working hours bonus (09:00 - 18:00)
      final endHour = candidateEndTime.hour + (candidateEndTime.minute > 0 ? 1 : 0);
      if (startTime.hour >= 9 && endHour <= 18) {
        score += 15.0;
      }

      // Unsociable hours penalty (< 08:00 or > 21:00)
      if (startTime.hour < 8 || endHour > 21) {
        score -= 25.0;
      }

      candidates.add(OptimalMeetingSlot(
        startTime: startTime,
        endTime: candidateEndTime,
        durationMinutes: durationMinutes,
        maxConflictCount: maxConflict,
        totalConflictWeight: totalConflictWeight,
        conflictedMemberIds: conflictedMembers.toList(),
        availableMemberIds: allFreeMembers.toList(),
        score: score,
      ));
    }

    // Rank candidate slots
    candidates.sort((a, b) {
      // 1. Zero-conflict first
      if (a.isZeroConflict && !b.isZeroConflict) return -1;
      if (!a.isZeroConflict && b.isZeroConflict) return 1;

      // 2. Score descending
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;

      // 3. Chronological start time ascending
      return a.startTime.compareTo(b.startTime);
    });

    return candidates;
  }
}
