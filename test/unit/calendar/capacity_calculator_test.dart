import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/calendar/domain/entities/schedule_models.dart';
import 'package:smart_calendar_hub/features/calendar/domain/services/capacity_calculator.dart';

void main() {
  group('CapacityCalculator Unit Tests', () {
    late CapacityCalculator calculator;
    final testDate = DateTime(2026, 10, 20);

    CalendarEvent makeEvent({
      required String id,
      required DateTime start,
      required DateTime end,
      bool isAnchored = false,
      bool isDeleted = false,
    }) {
      return CalendarEvent(
        id: id,
        userId: 'user_1',
        title: 'Event $id',
        startTime: start,
        endTime: end,
        isAnchored: isAnchored,
        isDeleted: isDeleted,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
    }

    setUp(() {
      calculator = CapacityCalculatorImpl();
    });

    test('Workload < 80% marks status as healthy with zero overage', () {
      // 5 hours total = 300 minutes (300 / 480 = 62.5%)
      final events = [
        makeEvent(
          id: '1',
          start: DateTime(2026, 10, 20, 9, 0),
          end: DateTime(2026, 10, 20, 11, 0), // 120 mins
          isAnchored: true,
        ),
        makeEvent(
          id: '2',
          start: DateTime(2026, 10, 20, 13, 0),
          end: DateTime(2026, 10, 20, 16, 0), // 180 mins
          isAnchored: false,
        ),
      ];

      final capacity = calculator.calculate(date: testDate, events: events, baselineCapacityMinutes: 480);

      expect(capacity.status, equals(CapacityStatus.healthy));
      expect(capacity.isHealthy, isTrue);
      expect(capacity.isModerate, isFalse);
      expect(capacity.isOverloaded, isFalse);
      expect(capacity.totalScheduledMinutes, equals(300));
      expect(capacity.anchorMinutes, equals(120));
      expect(capacity.flexibleMinutes, equals(180));
      expect(capacity.overageMinutes, equals(0));
      expect(capacity.workloadPercentage, closeTo(0.625, 0.001));
    });

    test('Workload between 80% and 100% marks status as moderate', () {
      // 7 hours total = 420 minutes (420 / 480 = 87.5%)
      final events = [
        makeEvent(
          id: '1',
          start: DateTime(2026, 10, 20, 9, 0),
          end: DateTime(2026, 10, 20, 16, 0), // 420 mins
        ),
      ];

      final capacity = calculator.calculate(date: testDate, events: events, baselineCapacityMinutes: 480);

      expect(capacity.status, equals(CapacityStatus.moderate));
      expect(capacity.isModerate, isTrue);
      expect(capacity.isHealthy, isFalse);
      expect(capacity.isOverloaded, isFalse);
      expect(capacity.totalScheduledMinutes, equals(420));
      expect(capacity.overageMinutes, equals(0));
      expect(capacity.workloadPercentage, closeTo(0.875, 0.001));
    });

    test('Workload > 100% marks status as overloaded and calculates overage minutes', () {
      // 9.5 hours total = 570 minutes (570 / 480 = 118.75%, overage = 90 mins)
      final events = [
        makeEvent(
          id: '1',
          start: DateTime(2026, 10, 20, 9, 0),
          end: DateTime(2026, 10, 20, 14, 0), // 300 mins (5h)
          isAnchored: true,
        ),
        makeEvent(
          id: '2',
          start: DateTime(2026, 10, 20, 14, 30),
          end: DateTime(2026, 10, 20, 19, 0), // 270 mins (4.5h)
          isAnchored: false,
        ),
      ];

      final capacity = calculator.calculate(date: testDate, events: events, baselineCapacityMinutes: 480);

      expect(capacity.status, equals(CapacityStatus.overloaded));
      expect(capacity.isOverloaded, isTrue);
      expect(capacity.totalScheduledMinutes, equals(570));
      expect(capacity.anchorMinutes, equals(300));
      expect(capacity.flexibleMinutes, equals(270));
      expect(capacity.overageMinutes, equals(90));
      expect(capacity.workloadPercentage, closeTo(1.1875, 0.001));
    });

    test('Ignores deleted events and events on other days', () {
      final events = [
        makeEvent(
          id: 'target_day',
          start: DateTime(2026, 10, 20, 9, 0),
          end: DateTime(2026, 10, 20, 11, 0), // 120 mins
        ),
        makeEvent(
          id: 'deleted_on_target',
          start: DateTime(2026, 10, 20, 11, 0),
          end: DateTime(2026, 10, 20, 13, 0),
          isDeleted: true,
        ),
        makeEvent(
          id: 'other_day',
          start: DateTime(2026, 10, 21, 9, 0),
          end: DateTime(2026, 10, 21, 17, 0),
        ),
      ];

      final capacity = calculator.calculate(date: testDate, events: events, baselineCapacityMinutes: 480);

      expect(capacity.totalScheduledMinutes, equals(120));
      expect(capacity.status, equals(CapacityStatus.healthy));
    });
  });
}
