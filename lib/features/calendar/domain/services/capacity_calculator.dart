import 'dart:math';
import '../entities/schedule_models.dart';

abstract class CapacityCalculator {
  WorkloadCapacity calculate({
    required DateTime date,
    required List<CalendarEvent> events,
    int baselineCapacityMinutes = 480,
  });
}

class CapacityCalculatorImpl implements CapacityCalculator {
  @override
  WorkloadCapacity calculate({
    required DateTime date,
    required List<CalendarEvent> events,
    int baselineCapacityMinutes = 480,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    int anchorMinutes = 0;
    int flexibleMinutes = 0;

    for (final event in events) {
      if (event.isDeleted || event.startTime == null || event.endTime == null) {
        continue;
      }
      // Check day intersection
      if (event.endTime!.isBefore(dayStart) || event.startTime!.isAfter(dayEnd)) {
        continue;
      }

      // Clamp event interval to this day
      final effectiveStart = event.startTime!.isBefore(dayStart) ? dayStart : event.startTime!;
      final effectiveEnd = event.endTime!.isAfter(dayEnd) ? dayEnd : event.endTime!;
      final durationMins = effectiveEnd.difference(effectiveStart).inMinutes;

      if (event.isAnchored) {
        anchorMinutes += durationMins;
      } else {
        flexibleMinutes += durationMins;
      }
    }

    final totalScheduled = anchorMinutes + flexibleMinutes;
    final workloadPercentage = baselineCapacityMinutes > 0
        ? totalScheduled / baselineCapacityMinutes
        : 0.0;

    final CapacityStatus status;
    if (workloadPercentage < 0.80) {
      status = CapacityStatus.healthy;
    } else if (workloadPercentage <= 1.00) {
      status = CapacityStatus.moderate;
    } else {
      status = CapacityStatus.overloaded;
    }

    final overageMinutes = max(0, totalScheduled - baselineCapacityMinutes);

    return WorkloadCapacity(
      date: DateTime(date.year, date.month, date.day),
      capacityMinutes: baselineCapacityMinutes,
      totalScheduledMinutes: totalScheduled,
      anchorMinutes: anchorMinutes,
      flexibleMinutes: flexibleMinutes,
      workloadPercentage: workloadPercentage,
      status: status,
      overageMinutes: overageMinutes,
    );
  }
}
