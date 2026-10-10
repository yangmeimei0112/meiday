import '../entities/schedule_models.dart';

abstract class AutoCascadeScheduler {
  /// Schedules an event to [targetStartTime], cascading flexible downstream events
  /// and halting at immovable anchors.
  ScheduleResult schedule({
    required List<CalendarEvent> existingEvents,
    required CalendarEvent movingEvent,
    required DateTime targetStartTime,
    int minBufferMinutes = 0,
    int minSplitMinutes = 15,
  });

  /// Resizes an event to [newDurationMinutes], cascading flexible downstream events.
  ScheduleResult resize({
    required List<CalendarEvent> existingEvents,
    required CalendarEvent resizingEvent,
    required int newDurationMinutes,
    int minBufferMinutes = 0,
    int minSplitMinutes = 15,
  });

  /// Scans for next contiguous free slot of [durationMinutes] within working hours.
  DateTime? findNextFreeSlot({
    required List<CalendarEvent> events,
    required DateTime searchStartTime,
    required int durationMinutes,
    int workingHoursStartHour = 8,
    int workingHoursEndHour = 22,
    int minBufferMinutes = 0,
  });
}

class AutoCascadeSchedulerImpl implements AutoCascadeScheduler {
  @override
  ScheduleResult schedule({
    required List<CalendarEvent> existingEvents,
    required CalendarEvent movingEvent,
    required DateTime targetStartTime,
    int minBufferMinutes = 0,
    int minSplitMinutes = 15,
  }) {
    final int durationMins = movingEvent.durationMinutes;
    final DateTime targetEndTime = targetStartTime.add(Duration(minutes: durationMins));

    final CalendarEvent updatedMovingEvent = movingEvent.copyWith(
      startTime: targetStartTime,
      endTime: targetEndTime,
      updatedAt: DateTime.now(),
    );

    // Filter out the moving event and sort others chronologically
    final otherEvents = existingEvents
        .where((e) => e.id != movingEvent.id && !e.isDeleted && e.startTime != null && e.endTime != null)
        .toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));

    final List<CalendarEvent> modifiedEvents = [updatedMovingEvent];
    CalendarEvent currentPusher = updatedMovingEvent;
    bool hasCascaded = false;

    // Filter downstream candidate events (events overlapping or starting after currentPusher)
    final downstreamCandidates = otherEvents.where((e) {
      return e.startTime!.isAfter(currentPusher.startTime!) ||
          (e.startTime!.isBefore(currentPusher.endTime!) && e.endTime!.isAfter(currentPusher.startTime!));
    }).toList();

    for (int i = 0; i < downstreamCandidates.length; i++) {
      final candidate = downstreamCandidates[i];

      // Buffer gap between current pusher end and candidate start
      final int bufferGapMinutes = candidate.startTime!.difference(currentPusher.endTime!).inMinutes;

      if (bufferGapMinutes >= minBufferMinutes) {
        // Buffer absorbs displacement! Cascade terminates cleanly.
        break;
      }

      // Buffer gap violated! Overlap deficit exists.
      final int overlapDeficit = minBufferMinutes - bufferGapMinutes;

      if (candidate.isAnchored) {
        // Check if movingEvent is also an anchor manually dragged onto an anchor
        if (movingEvent.isAnchored && currentPusher.id == movingEvent.id) {
          return ScheduleResult(
            modifiedEvents: const [],
            conflicts: [
              ScheduleConflict.anchorClash(
                blockedEvent: updatedMovingEvent,
                proposedStartTime: targetStartTime,
                collidingAnchor: candidate,
                overlapMinutes: overlapDeficit,
              ),
            ],
            type: ScheduleResultType.haltedWithConflict,
          );
        }

        // BOUNDARY HALT: Downstream Anchor cannot be displaced!
        final proposals = _generateProposals(
          collidingTask: currentPusher,
          anchor: candidate,
          otherEvents: otherEvents,
          minBufferMinutes: minBufferMinutes,
          minSplitMinutes: minSplitMinutes,
        );

        final int overlapMinutes = currentPusher.endTime!.difference(candidate.startTime!).inMinutes;

        return ScheduleResult(
          modifiedEvents: modifiedEvents,
          conflicts: [
            ScheduleConflict.boundaryHalt(
              blockedEvent: currentPusher,
              proposedStartTime: currentPusher.startTime!,
              collidingAnchor: candidate,
              overlapMinutes: overlapMinutes > 0 ? overlapMinutes : overlapDeficit,
              proposals: proposals,
            ),
          ],
          type: ScheduleResultType.haltedWithConflict,
        );
      } else {
        // Flexible task: Push downstream
        final DateTime newCandidateStart = currentPusher.endTime!.add(Duration(minutes: minBufferMinutes));
        final DateTime newCandidateEnd = newCandidateStart.add(Duration(minutes: candidate.durationMinutes));

        final shiftedCandidate = candidate.copyWith(
          startTime: newCandidateStart,
          endTime: newCandidateEnd,
          updatedAt: DateTime.now(),
        );

        modifiedEvents.add(shiftedCandidate);
        currentPusher = shiftedCandidate;
        hasCascaded = true;
      }
    }

    return ScheduleResult(
      modifiedEvents: modifiedEvents,
      conflicts: const [],
      type: hasCascaded ? ScheduleResultType.cascaded : ScheduleResultType.clean,
    );
  }

  @override
  ScheduleResult resize({
    required List<CalendarEvent> existingEvents,
    required CalendarEvent resizingEvent,
    required int newDurationMinutes,
    int minBufferMinutes = 0,
    int minSplitMinutes = 15,
  }) {
    final startTime = resizingEvent.startTime ?? DateTime.now();
    final newEndTime = startTime.add(Duration(minutes: newDurationMinutes));

    final resized = resizingEvent.copyWith(
      startTime: startTime,
      endTime: newEndTime,
      estimatedMinutes: newDurationMinutes,
      updatedAt: DateTime.now(),
    );

    return schedule(
      existingEvents: existingEvents,
      movingEvent: resized,
      targetStartTime: startTime,
      minBufferMinutes: minBufferMinutes,
      minSplitMinutes: minSplitMinutes,
    );
  }

  List<ProposalAlternative> _generateProposals({
    required CalendarEvent collidingTask,
    required CalendarEvent anchor,
    required List<CalendarEvent> otherEvents,
    required int minBufferMinutes,
    required int minSplitMinutes,
  }) {
    final List<ProposalAlternative> proposals = [];

    // Proposal 1: Shift Past Anchor
    final DateTime shiftStart = anchor.endTime!.add(Duration(minutes: minBufferMinutes));
    final DateTime shiftEnd = shiftStart.add(Duration(minutes: collidingTask.durationMinutes));
    proposals.add(
      ProposalAlternative.shiftPastAnchor(
        label: '順延至會議後 (${_formatTime(shiftStart)})',
        description: '將「${collidingTask.title}」排程推遲至「${anchor.title}」結束後開始',
        newStartTime: shiftStart,
        newEndTime: shiftEnd,
      ),
    );

    // Proposal 2: Split Task
    final int preAnchorMinutes = anchor.startTime!.difference(collidingTask.startTime!).inMinutes;
    final int remainingMinutes = collidingTask.durationMinutes - preAnchorMinutes;

    if (preAnchorMinutes >= minSplitMinutes && remainingMinutes >= minSplitMinutes) {
      final part1 = collidingTask.copyWith(
        id: '${collidingTask.id}_part1',
        title: '${collidingTask.title} (第 1 階段)',
        startTime: collidingTask.startTime,
        endTime: anchor.startTime,
        estimatedMinutes: preAnchorMinutes,
      );
      final part2 = collidingTask.copyWith(
        id: '${collidingTask.id}_part2',
        title: '${collidingTask.title} (第 2 階段)',
        startTime: shiftStart,
        endTime: shiftStart.add(Duration(minutes: remainingMinutes)),
        estimatedMinutes: remainingMinutes,
      );
      proposals.add(
        ProposalAlternative.splitBlock(
          label: '拆分為兩段 ($preAnchorMinutes分 + $remainingMinutes分)',
          description: '會議前執行 $preAnchorMinutes 分鐘，會議後接續執行 $remainingMinutes 分鐘',
          part1: part1,
          part2: part2,
        ),
      );
    }

    // Proposal 3: Trim Buffer / Duration
    if (preAnchorMinutes >= minSplitMinutes) {
      proposals.add(
        ProposalAlternative.trimBuffer(
          label: '縮減工時至 $preAnchorMinutes 分鐘 (會議前完成)',
          description: '壓縮工時以剛好在「${anchor.title}」前完成',
          compressedDurationMinutes: preAnchorMinutes,
          proposedEndTime: anchor.startTime!,
        ),
      );
    }

    // Proposal 4: Suggest Next Free Slot
    final nextFreeSlot = findNextFreeSlot(
      events: [...otherEvents, anchor],
      searchStartTime: anchor.endTime!,
      durationMinutes: collidingTask.durationMinutes,
      minBufferMinutes: minBufferMinutes,
    );

    if (nextFreeSlot != null) {
      proposals.add(
        ProposalAlternative.alternativeSlot(
          label: '移至空檔時段 (${_formatTime(nextFreeSlot)})',
          description: '移至本日後續完全空閒的完整時段',
          slotStartTime: nextFreeSlot,
          slotEndTime: nextFreeSlot.add(Duration(minutes: collidingTask.durationMinutes)),
        ),
      );
    }

    return proposals;
  }

  @override
  DateTime? findNextFreeSlot({
    required List<CalendarEvent> events,
    required DateTime searchStartTime,
    required int durationMinutes,
    int workingHoursStartHour = 8,
    int workingHoursEndHour = 22,
    int minBufferMinutes = 0,
  }) {
    final dayStart = DateTime(searchStartTime.year, searchStartTime.month, searchStartTime.day, workingHoursStartHour);
    final dayEnd = DateTime(searchStartTime.year, searchStartTime.month, searchStartTime.day, workingHoursEndHour);

    DateTime candidateStart = searchStartTime.isBefore(dayStart) ? dayStart : searchStartTime;

    final sorted = events
        .where((e) => !e.isDeleted && e.startTime != null && e.endTime != null && e.endTime!.isAfter(candidateStart))
        .toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));

    for (final event in sorted) {
      final potentialEnd = candidateStart.add(Duration(minutes: durationMinutes));
      if (potentialEnd.isBefore(event.startTime!) || potentialEnd.isAtSameMomentAs(event.startTime!)) {
        return candidateStart;
      }
      if (event.endTime!.isAfter(candidateStart)) {
        candidateStart = event.endTime!.add(Duration(minutes: minBufferMinutes));
      }
    }

    final potentialEnd = candidateStart.add(Duration(minutes: durationMinutes));
    if (potentialEnd.isBefore(dayEnd) || potentialEnd.isAtSameMomentAs(dayEnd)) {
      return candidateStart;
    }

    return null;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
