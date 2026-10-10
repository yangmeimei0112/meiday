import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/availability_slot.dart';
import 'package:smart_calendar_hub/features/social/domain/services/optimal_meeting_finder.dart';

void main() {
  group('OptimalMeetingFinder Unit Tests', () {
    late OptimalMeetingFinder finder;

    setUp(() {
      finder = OptimalMeetingFinder();
    });

    test('findOptimalSlots correctly finds 0-conflict contiguous slots for 60-minute duration', () {
      final baseDate = DateTime(2026, 10, 10);
      final slots = <AvailabilitySlot>[];

      // Create 8 slots (09:00 - 13:00):
      // 09:00 - 09:30: 1 busy
      // 09:30 - 10:00: 0 busy (free)
      // 10:00 - 10:30: 0 busy (free)
      // 10:30 - 11:00: 0 busy (free)
      // 11:00 - 11:30: 2 busy
      // 11:30 - 12:00: 0 busy (free)
      // 12:00 - 12:30: 0 busy (free)
      // 12:30 - 13:00: 0 busy (free)
      final busyCounts = [1, 0, 0, 0, 2, 0, 0, 0];
      for (int i = 0; i < 8; i++) {
        final start = baseDate.add(Duration(hours: 9, minutes: i * 30));
        final end = start.add(const Duration(minutes: 30));
        slots.add(AvailabilitySlot(
          startTime: start,
          endTime: end,
          totalMembers: 3,
          busyCount: busyCounts[i],
          busyMemberIds: busyCounts[i] > 0 ? ['u1'] : const [],
          freeMemberIds: busyCounts[i] == 0 ? ['u1', 'u2', 'u3'] : ['u2', 'u3'],
        ));
      }

      // Looking for 60-min meeting (2 consecutive 30-min slots)
      final candidates = finder.findOptimalSlots(
        availabilitySlots: slots,
        durationMinutes: 60,
      );

      expect(candidates, isNotEmpty);

      // Verify zero-conflict candidates come first
      final zeroConflictCandidates = candidates.where((c) => c.isZeroConflict).toList();
      expect(zeroConflictCandidates, isNotEmpty);

      // 09:30 - 10:30 is 0-conflict
      // 10:00 - 11:00 is 0-conflict
      // 11:30 - 12:30 is 0-conflict
      // 12:00 - 13:00 is 0-conflict
      expect(zeroConflictCandidates.length, equals(4));

      // Candidate spanning 09:00 - 10:00 has maxConflict = 1 and is ranked after 0-conflict ones
      final conflicted = candidates.where((c) => !c.isZeroConflict).toList();
      expect(conflicted, isNotEmpty);

      // First candidate in results must be 0-conflict
      expect(candidates.first.isZeroConflict, isTrue);
    });

    test('Score ranks working hours higher than unsociable hours', () {
      final baseDate = DateTime(2026, 10, 10);
      final slots = <AvailabilitySlot>[
        // Slot at 06:00 (early morning unsociable): 0 busy
        AvailabilitySlot(
          startTime: baseDate.add(const Duration(hours: 6)),
          endTime: baseDate.add(const Duration(hours: 6, minutes: 30)),
          totalMembers: 2,
          busyCount: 0,
        ),
        // Slot at 14:00 (prime working hours): 0 busy
        AvailabilitySlot(
          startTime: baseDate.add(const Duration(hours: 14)),
          endTime: baseDate.add(const Duration(hours: 14, minutes: 30)),
          totalMembers: 2,
          busyCount: 0,
        ),
      ];

      final candidates = finder.findOptimalSlots(
        availabilitySlots: slots,
        durationMinutes: 30,
      );

      expect(candidates.length, equals(2));
      final primeSlot = candidates.firstWhere((c) => c.startTime.hour == 14);
      final earlySlot = candidates.firstWhere((c) => c.startTime.hour == 6);

      expect(primeSlot.score, greaterThan(earlySlot.score));
      // First ranked is prime working hours
      expect(candidates.first, equals(primeSlot));
    });

    test('Rejects candidates spanning across midnight into next calendar day', () {
      final baseDate = DateTime(2026, 10, 10);
      final slots = <AvailabilitySlot>[
        AvailabilitySlot(
          startTime: DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 30),
          endTime: DateTime(baseDate.year, baseDate.month, baseDate.day + 1, 0, 0),
          totalMembers: 2,
          busyCount: 0,
        ),
        AvailabilitySlot(
          startTime: DateTime(baseDate.year, baseDate.month, baseDate.day + 1, 0, 0),
          endTime: DateTime(baseDate.year, baseDate.month, baseDate.day + 1, 0, 30),
          totalMembers: 2,
          busyCount: 0,
        ),
      ];

      // A 60-min meeting would span 23:30 to 00:30 (cross midnight)
      final candidates = finder.findOptimalSlots(
        availabilitySlots: slots,
        durationMinutes: 60,
      );

      expect(candidates, isEmpty, reason: 'Meeting cannot cross midnight boundary');
    });

    test('15-minute and 45-minute meetings calculate exact duration end times', () {
      final baseDate = DateTime(2026, 10, 10, 10, 0);
      final slots = <AvailabilitySlot>[
        AvailabilitySlot(
          startTime: baseDate,
          endTime: baseDate.add(const Duration(minutes: 30)),
          totalMembers: 2,
          busyCount: 0,
        ),
        AvailabilitySlot(
          startTime: baseDate.add(const Duration(minutes: 30)),
          endTime: baseDate.add(const Duration(minutes: 60)),
          totalMembers: 2,
          busyCount: 0,
        ),
      ];

      // 15-minute meeting
      final candidates15 = finder.findOptimalSlots(
        availabilitySlots: slots,
        durationMinutes: 15,
      );
      expect(candidates15, isNotEmpty);
      expect(candidates15.first.durationMinutes, equals(15));
      expect(candidates15.first.endTime, equals(baseDate.add(const Duration(minutes: 15))));

      // 45-minute meeting
      final candidates45 = finder.findOptimalSlots(
        availabilitySlots: slots,
        durationMinutes: 45,
      );
      expect(candidates45, isNotEmpty);
      expect(candidates45.first.durationMinutes, equals(45));
      expect(candidates45.first.endTime, equals(baseDate.add(const Duration(minutes: 45))));
    });
  });
}
