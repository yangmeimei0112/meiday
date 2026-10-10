import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/availability_slot.dart';
import '../../domain/entities/member_schedule.dart';
import '../../domain/services/availability_calculator.dart';
import '../../domain/services/optimal_meeting_finder.dart';

/// Heatmap visibility toggle state.
final isHeatmapActiveProvider = StateProvider<bool>((ref) => false);

/// Availability calculator service provider.
final availabilityCalculatorProvider = Provider<AvailabilityCalculator>((ref) {
  return AvailabilityCalculator();
});

/// Optimal meeting finder service provider.
final optimalMeetingFinderProvider = Provider<OptimalMeetingFinder>((ref) {
  return OptimalMeetingFinder();
});

/// Mock or connected member schedules for multi-person availability demo.
final memberSchedulesProvider = StateProvider<List<MemberSchedule>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return [
    MemberSchedule(
      memberId: 'user_self',
      memberName: '我 (Self)',
      colorValue: 0xFF6366F1,
      busySpans: [
        BusyTimeSpan(
          start: today.add(const Duration(hours: 10)),
          end: today.add(const Duration(hours: 11, minutes: 30)),
          eventTitle: '產品討論會',
        ),
        BusyTimeSpan(
          start: today.add(const Duration(hours: 15)),
          end: today.add(const Duration(hours: 16)),
          eventTitle: '客戶電話',
        ),
      ],
    ),
    MemberSchedule(
      memberId: 'user_partner',
      memberName: '伴侶 (Partner)',
      colorValue: 0xFFEC4899,
      busySpans: [
        BusyTimeSpan(
          start: today.add(const Duration(hours: 9)),
          end: today.add(const Duration(hours: 10, minutes: 30)),
          eventTitle: '早會',
        ),
        BusyTimeSpan(
          start: today.add(const Duration(hours: 14)),
          end: today.add(const Duration(hours: 15, minutes: 30)),
          eventTitle: '瑜珈課',
        ),
      ],
    ),
    MemberSchedule(
      memberId: 'user_colleague',
      memberName: '同事 (Colleague)',
      colorValue: 0xFF06B6D4,
      busySpans: [
        BusyTimeSpan(
          start: today.add(const Duration(hours: 11)),
          end: today.add(const Duration(hours: 12)),
          eventTitle: '代碼評審',
        ),
        BusyTimeSpan(
          start: today.add(const Duration(hours: 16)),
          end: today.add(const Duration(hours: 17, minutes: 30)),
          eventTitle: '部門週會',
        ),
      ],
    ),
  ];
});

/// Calculates 30-min availability slots for a specific calendar day.
final dayAvailabilitySlotsProvider =
    Provider.family<List<AvailabilitySlot>, DateTime>((ref, day) {
  final schedules = ref.watch(memberSchedulesProvider);
  final calculator = ref.watch(availabilityCalculatorProvider);

  final startOfDay = DateTime(day.year, day.month, day.day, 0, 0);
  final endOfDay = DateTime(day.year, day.month, day.day, 24, 0);

  return calculator.calculateSlots(
    rangeStart: startOfDay,
    rangeEnd: endOfDay,
    memberSchedules: schedules,
  );
});
