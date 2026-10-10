import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/member_schedule.dart';
import 'package:smart_calendar_hub/features/social/domain/services/availability_calculator.dart';

void main() {
  group('AvailabilityCalculator Unit Tests', () {
    late AvailabilityCalculator calculator;

    setUp(() {
      calculator = AvailabilityCalculator();
    });

    test('0 members edge case produces 0 density and zero-conflict slots', () {
      final rangeStart = DateTime(2026, 10, 10, 9, 0);
      final rangeEnd = DateTime(2026, 10, 10, 11, 0); // 2 hours = 4 slots

      final slots = calculator.calculateSlots(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        memberSchedules: const [],
      );

      expect(slots.length, equals(4));
      expect(slots.every((s) => s.totalMembers == 0), isTrue);
      expect(slots.every((s) => s.busyCount == 0), isTrue);
      expect(slots.every((s) => s.busyDensity == 0.0), isTrue);
      expect(slots.every((s) => s.freeRatio == 1.0), isTrue);
      expect(slots.every((s) => s.isZeroConflict), isTrue);
    });

    test('Single member with no commitments is 100% free across entire range', () {
      final rangeStart = DateTime(2026, 10, 10, 9, 0);
      final rangeEnd = DateTime(2026, 10, 10, 10, 0); // 1 hour = 2 slots

      const member = MemberSchedule(
        memberId: 'm1',
        memberName: 'Alice',
        colorValue: 0xFF123456,
        busySpans: [],
      );

      final slots = calculator.calculateSlots(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        memberSchedules: [member],
      );

      expect(slots.length, equals(2));
      expect(slots.first.isZeroConflict, isTrue);
      expect(slots.first.freeMemberIds, contains('m1'));
      expect(slots.first.busyCount, equals(0));
    });

    test('Exact 30-minute boundary handling does not bleed into adjacent slots', () {
      final rangeStart = DateTime(2026, 10, 10, 9, 0);
      final rangeEnd = DateTime(2026, 10, 10, 11, 0); // 4 slots: 09:00, 09:30, 10:00, 10:30

      // Busy exactly between 09:30 and 10:30
      final member = MemberSchedule(
        memberId: 'm1',
        memberName: 'Bob',
        colorValue: 0xFF123456,
        busySpans: [
          BusyTimeSpan(
            start: DateTime(2026, 10, 10, 9, 30),
            end: DateTime(2026, 10, 10, 10, 30),
          ),
        ],
      );

      final slots = calculator.calculateSlots(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        memberSchedules: [member],
      );

      expect(slots.length, equals(4));

      // 09:00 - 09:30: Free (touching 09:30 boundary must not be marked busy)
      expect(slots[0].isZeroConflict, isTrue);
      expect(slots[0].busyCount, equals(0));

      // 09:30 - 10:00: Busy
      expect(slots[1].isZeroConflict, isFalse);
      expect(slots[1].busyCount, equals(1));

      // 10:00 - 10:30: Busy
      expect(slots[2].isZeroConflict, isFalse);
      expect(slots[2].busyCount, equals(1));

      // 10:30 - 11:00: Free (touching 10:30 boundary must not be marked busy)
      expect(slots[3].isZeroConflict, isTrue);
      expect(slots[3].busyCount, equals(0));
    });

    test('Multiple members density metrics and dynamic color alpha interpolation', () {
      final slotStart = DateTime(2026, 10, 10, 14, 0);
      final slotEnd = DateTime(2026, 10, 10, 14, 30);

      // 4 members: 2 busy, 2 free
      final schedules = [
        MemberSchedule(
          memberId: 'm1',
          memberName: 'M1',
          colorValue: 0,
          busySpans: [BusyTimeSpan(start: slotStart, end: slotEnd)],
        ),
        MemberSchedule(
          memberId: 'm2',
          memberName: 'M2',
          colorValue: 0,
          busySpans: [BusyTimeSpan(start: slotStart, end: slotEnd)],
        ),
        const MemberSchedule(
          memberId: 'm3',
          memberName: 'M3',
          colorValue: 0,
          busySpans: [],
        ),
        const MemberSchedule(
          memberId: 'm4',
          memberName: 'M4',
          colorValue: 0,
          busySpans: [],
        ),
      ];

      final slots = calculator.calculateSlots(
        rangeStart: slotStart,
        rangeEnd: slotEnd,
        memberSchedules: schedules,
      );

      expect(slots.length, equals(1));
      final slot = slots.first;
      expect(slot.totalMembers, equals(4));
      expect(slot.busyCount, equals(2));
      expect(slot.freeCount, equals(2));
      expect(slot.busyDensity, equals(0.5));
      expect(slot.freeRatio, equals(0.5));
      expect(slot.isZeroConflict, isFalse);
      expect(slot.isFullyBooked, isFalse);

      // Partial busy should use amber color (0xFFF59E0B)
      expect(slot.color.toARGB32() & 0x00FFFFFF, equals(0x00F59E0B));
    });
  });
}
