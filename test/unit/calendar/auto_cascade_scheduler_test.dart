import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/calendar/domain/entities/schedule_models.dart';
import 'package:smart_calendar_hub/features/calendar/domain/services/auto_cascade_scheduler.dart';

void main() {
  group('AutoCascadeScheduler Unit Tests', () {
    late AutoCascadeScheduler scheduler;
    final baseDate = DateTime(2026, 10, 15);

    DateTime time(int hour, int minute) =>
        DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);

    CalendarEvent createEvent({
      required String id,
      required String title,
      required DateTime start,
      required DateTime end,
      bool isAnchored = false,
      int estimatedMinutes = 60,
    }) {
      return CalendarEvent(
        id: id,
        userId: 'test_user',
        title: title,
        startTime: start,
        endTime: end,
        isAnchored: isAnchored,
        estimatedMinutes: estimatedMinutes,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
    }

    setUp(() {
      scheduler = AutoCascadeSchedulerImpl();
    });

    test('Clean schedule when buffer absorbs displacement without shifting downstream', () {
      final taskA = createEvent(
        id: 'task_a',
        title: 'Task A',
        start: time(9, 0),
        end: time(10, 0),
      );
      final taskB = createEvent(
        id: 'task_b',
        title: 'Task B',
        start: time(12, 0),
        end: time(13, 0),
      );

      // Move Task A to 10:00 - 11:00 (1 hour buffer before Task B at 12:00)
      final result = scheduler.schedule(
        existingEvents: [taskA, taskB],
        movingEvent: taskA,
        targetStartTime: time(10, 0),
        minBufferMinutes: 0,
      );

      expect(result.type, equals(ScheduleResultType.clean));
      expect(result.hasConflicts, isFalse);
      expect(result.modifiedEvents.length, equals(1));
      expect(result.modifiedEvents.first.startTime, equals(time(10, 0)));
      expect(result.modifiedEvents.first.endTime, equals(time(11, 0)));
    });

    test('Elastic cascade propagates downstream when flexible events overlap', () {
      final taskA = createEvent(
        id: 'task_a',
        title: 'Task A',
        start: time(9, 0),
        end: time(10, 0),
      );
      final taskB = createEvent(
        id: 'task_b',
        title: 'Task B',
        start: time(10, 0),
        end: time(11, 0),
      );
      final taskC = createEvent(
        id: 'task_c',
        title: 'Task C',
        start: time(11, 0),
        end: time(12, 0),
      );

      // Move Task A to 9:30 - 10:30 -> Task B pushed to 10:30-11:30 -> Task C pushed to 11:30-12:30
      final result = scheduler.schedule(
        existingEvents: [taskA, taskB, taskC],
        movingEvent: taskA,
        targetStartTime: time(9, 30),
        minBufferMinutes: 0,
      );

      expect(result.type, equals(ScheduleResultType.cascaded));
      expect(result.hasConflicts, isFalse);
      expect(result.modifiedEvents.length, equals(3));

      final updatedA = result.modifiedEvents.firstWhere((e) => e.id == 'task_a');
      final updatedB = result.modifiedEvents.firstWhere((e) => e.id == 'task_b');
      final updatedC = result.modifiedEvents.firstWhere((e) => e.id == 'task_c');

      expect(updatedA.startTime, equals(time(9, 30)));
      expect(updatedA.endTime, equals(time(10, 30)));

      expect(updatedB.startTime, equals(time(10, 30)));
      expect(updatedB.endTime, equals(time(11, 30)));

      expect(updatedC.startTime, equals(time(11, 30)));
      expect(updatedC.endTime, equals(time(12, 30)));
    });

    test('Boundary halt occurs and immutably protects Anchor meeting when flexible task encroaches', () {
      final taskA = createEvent(
        id: 'task_a',
        title: 'Draft Report',
        start: time(9, 0),
        end: time(10, 0),
      );
      final meetingB = createEvent(
        id: 'meeting_b',
        title: 'Team Sync (Anchor)',
        start: time(10, 30),
        end: time(11, 30),
        isAnchored: true, // IMMUTABLE TRACK 1
      );

      // User moves Task A to 10:00 - 11:00, overlapping Meeting B by 30 minutes
      final result = scheduler.schedule(
        existingEvents: [taskA, meetingB],
        movingEvent: taskA,
        targetStartTime: time(10, 0),
        minBufferMinutes: 0,
        minSplitMinutes: 15,
      );

      expect(result.type, equals(ScheduleResultType.haltedWithConflict));
      expect(result.hasConflicts, isTrue);
      expect(result.conflicts.length, equals(1));

      final conflict = result.conflicts.first;
      expect(conflict.type, equals(ConflictType.boundaryHalt));
      expect(conflict.blockedEvent.id, equals('task_a'));
      expect(conflict.collidingAnchor.id, equals('meeting_b'));
      expect(conflict.overlapMinutes, equals(30));

      // Meeting B was NOT modified or shifted
      expect(result.modifiedEvents.any((e) => e.id == 'meeting_b'), isFalse);

      // Verify proposal alternatives are generated
      expect(conflict.proposals.isNotEmpty, isTrue);

      // 1. Shift Past Anchor proposal
      final shiftProp = conflict.proposals.firstWhere(
        (p) => p.type == ProposalAlternativeType.shiftPastAnchor,
      );
      expect(shiftProp.newStartTime, equals(time(11, 30)));
      expect(shiftProp.newEndTime, equals(time(12, 30)));

      // 2. Split Block proposal (30 min before meeting + 30 min after meeting)
      final splitProp = conflict.proposals.firstWhere(
        (p) => p.type == ProposalAlternativeType.splitBlock,
      );
      expect(splitProp.part1?.durationMinutes, equals(30));
      expect(splitProp.part2?.durationMinutes, equals(30));

      // 3. Trim Buffer proposal (compress duration to 30 min before meeting)
      final trimProp = conflict.proposals.firstWhere(
        (p) => p.type == ProposalAlternativeType.trimBuffer,
      );
      expect(trimProp.compressedDurationMinutes, equals(30));
      expect(trimProp.proposedEndTime, equals(time(10, 30)));
    });

    test('Resize triggers downstream cascade with buffer compression', () {
      final taskA = createEvent(
        id: 'task_a',
        title: 'Task A',
        start: time(9, 0),
        end: time(10, 0),
        estimatedMinutes: 60,
      );
      final taskB = createEvent(
        id: 'task_b',
        title: 'Task B',
        start: time(10, 15),
        end: time(11, 15),
      );

      // Extending Task A from 60 mins to 90 mins (9:00 - 10:30)
      // Buffer gap was 15 mins (10:00 - 10:15). Now 10:30 > 10:15 -> Task B shifted to 10:30 - 11:30
      final result = scheduler.resize(
        existingEvents: [taskA, taskB],
        resizingEvent: taskA,
        newDurationMinutes: 90,
        minBufferMinutes: 0,
      );

      expect(result.type, equals(ScheduleResultType.cascaded));
      expect(result.modifiedEvents.length, equals(2));

      final updatedA = result.modifiedEvents.firstWhere((e) => e.id == 'task_a');
      final updatedB = result.modifiedEvents.firstWhere((e) => e.id == 'task_b');

      expect(updatedA.durationMinutes, equals(90));
      expect(updatedA.endTime, equals(time(10, 30)));
      expect(updatedB.startTime, equals(time(10, 30)));
      expect(updatedB.endTime, equals(time(11, 30)));
    });

    test('Direct anchor-to-anchor manual collision halts with anchorClash conflict', () {
      final anchor1 = createEvent(
        id: 'anchor_1',
        title: 'Board Meeting',
        start: time(10, 0),
        end: time(11, 0),
        isAnchored: true,
      );
      final anchor2 = createEvent(
        id: 'anchor_2',
        title: 'Client Call',
        start: time(14, 0),
        end: time(15, 0),
        isAnchored: true,
      );

      // Manually moving anchor_2 directly onto anchor_1
      final result = scheduler.schedule(
        existingEvents: [anchor1, anchor2],
        movingEvent: anchor2,
        targetStartTime: time(10, 30),
      );

      expect(result.type, equals(ScheduleResultType.haltedWithConflict));
      expect(result.conflicts.length, equals(1));
      expect(result.conflicts.first.type, equals(ConflictType.anchorClash));
      expect(result.conflicts.first.collidingAnchor.id, equals('anchor_1'));
    });

    test('findNextFreeSlot locates contiguous free window within working hours', () {
      final anchor1 = createEvent(
        id: 'anchor_1',
        title: 'Morning Sync',
        start: time(9, 0),
        end: time(10, 0),
        isAnchored: true,
      );
      final anchor2 = createEvent(
        id: 'anchor_2',
        title: 'Lunch',
        start: time(10, 30),
        end: time(11, 30),
        isAnchored: true,
      );

      // Search for a 60-minute free slot starting at 10:00.
      // Gap between 10:00 and 10:30 is only 30m, so it cannot fit 60m.
      // After lunch (11:30), the slot is completely free.
      final slot = scheduler.findNextFreeSlot(
        events: [anchor1, anchor2],
        searchStartTime: time(10, 0),
        durationMinutes: 60,
      );

      expect(slot, equals(time(11, 30)));
    });
  });
}
