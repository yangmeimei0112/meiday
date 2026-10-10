import '../entities/availability_slot.dart';
import '../entities/member_schedule.dart';

class AvailabilityCalculator {
  static const int defaultIntervalMinutes = 30;

  List<AvailabilitySlot> calculateSlots({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<MemberSchedule> memberSchedules,
    int intervalMinutes = defaultIntervalMinutes,
  }) {
    if (rangeEnd.isBefore(rangeStart) || intervalMinutes <= 0) {
      return const [];
    }

    final totalMembers = memberSchedules.length;
    final slots = <AvailabilitySlot>[];

    var current = rangeStart;
    while (current.isBefore(rangeEnd)) {
      final slotEnd = current.add(Duration(minutes: intervalMinutes));
      final effectiveEnd = slotEnd.isAfter(rangeEnd) ? rangeEnd : slotEnd;

      final busyIds = <String>[];
      final freeIds = <String>[];

      for (final member in memberSchedules) {
        final isBusy = member.busySpans.any((span) =>
            span.overlaps(current, effectiveEnd));

        if (isBusy) {
          busyIds.add(member.memberId);
        } else {
          freeIds.add(member.memberId);
        }
      }

      slots.add(AvailabilitySlot(
        startTime: current,
        endTime: effectiveEnd,
        totalMembers: totalMembers,
        busyCount: busyIds.length,
        busyMemberIds: busyIds,
        freeMemberIds: freeIds,
      ));

      current = slotEnd;
    }

    return slots;
  }
}
