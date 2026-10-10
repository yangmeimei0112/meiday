import 'package:drift/drift.dart' show Value;
import 'package:meta/meta.dart';
import '../../../../core/database/app_database.dart';

/// Supported view modes for the ChronoHub calendar canvas.
enum CalendarViewMode {
  month,
  week,
  threeDay,
  day,
}

/// Domain entity representing a calendar event or GTD time block.
@immutable
class CalendarEvent {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? location;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isAllDay;
  final bool isAnchored; // Track 1: Anchored (true) vs Track 2: Flexible (false)
  final String status;
  final int priority;
  final int estimatedMinutes;
  final int actualMinutes;
  final int? color;
  final String? recurrenceRule;
  final double taskScore;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.location,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.isAnchored = false,
    this.status = 'pending',
    this.priority = 0,
    this.estimatedMinutes = 30,
    this.actualMinutes = 0,
    this.color,
    this.recurrenceRule,
    this.taskScore = 0.0,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get isAnchor => isAnchored;
  bool get isFlexible => !isAnchored;

  Duration get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return Duration(minutes: estimatedMinutes);
  }

  int get durationMinutes => duration.inMinutes;

  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    bool? isAnchored,
    String? status,
    int? priority,
    int? estimatedMinutes,
    int? actualMinutes,
    int? color,
    String? recurrenceRule,
    double? taskScore,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      isAnchored: isAnchored ?? this.isAnchored,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      color: color ?? this.color,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      taskScore: taskScore ?? this.taskScore,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Create a domain [CalendarEvent] from Drift [CalendarEventData].
  factory CalendarEvent.fromData(CalendarEventData data) {
    return CalendarEvent(
      id: data.id,
      userId: data.userId,
      title: data.title,
      description: data.description,
      location: data.location,
      startTime: data.startTime,
      endTime: data.endTime,
      isAllDay: data.isAllDay,
      isAnchored: data.isAnchored,
      status: data.status,
      priority: data.priority,
      estimatedMinutes: data.estimatedMinutes,
      actualMinutes: data.actualMinutes,
      color: data.color,
      recurrenceRule: data.recurrenceRule,
      taskScore: data.taskScore,
      version: data.version,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      isDeleted: data.isDeleted,
    );
  }

  /// Convert to Drift companion for database operations.
  CalendarEventsCompanion toCompanion() {
    return CalendarEventsCompanion(
      id: Value(id),
      userId: Value(userId),
      title: Value(title),
      description: Value(description),
      location: Value(location),
      startTime: Value(startTime),
      endTime: Value(endTime),
      isAllDay: Value(isAllDay),
      isAnchored: Value(isAnchored),
      status: Value(status),
      priority: Value(priority),
      estimatedMinutes: Value(estimatedMinutes),
      actualMinutes: Value(actualMinutes),
      color: Value(color),
      recurrenceRule: Value(recurrenceRule),
      taskScore: Value(taskScore),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CalendarEvent(id: $id, title: $title, start: $startTime, end: $endTime, isAnchored: $isAnchored)';
}

/// Proposal alternative types for resolving schedule collisions.
enum ProposalAlternativeType {
  shiftPastAnchor,
  splitBlock,
  trimBuffer,
  alternativeSlot,
}

/// Non-blocking resolution proposal presented to user when an anchor is reached.
@immutable
class ProposalAlternative {
  final ProposalAlternativeType type;
  final String label;
  final String description;
  final DateTime? newStartTime;
  final DateTime? newEndTime;
  final CalendarEvent? part1;
  final CalendarEvent? part2;
  final int? compressedDurationMinutes;
  final DateTime? proposedEndTime;
  final DateTime? slotStartTime;
  final DateTime? slotEndTime;
  final List<CalendarEvent> previewCascade;

  const ProposalAlternative({
    required this.type,
    required this.label,
    required this.description,
    this.newStartTime,
    this.newEndTime,
    this.part1,
    this.part2,
    this.compressedDurationMinutes,
    this.proposedEndTime,
    this.slotStartTime,
    this.slotEndTime,
    this.previewCascade = const [],
  });

  /// Factory constructors for clear creation:
  factory ProposalAlternative.shiftPastAnchor({
    required String label,
    required String description,
    required DateTime newStartTime,
    required DateTime newEndTime,
    List<CalendarEvent> previewCascade = const [],
  }) {
    return ProposalAlternative(
      type: ProposalAlternativeType.shiftPastAnchor,
      label: label,
      description: description,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
      previewCascade: previewCascade,
    );
  }

  factory ProposalAlternative.splitBlock({
    required String label,
    required String description,
    required CalendarEvent part1,
    required CalendarEvent part2,
    List<CalendarEvent> previewCascade = const [],
  }) {
    return ProposalAlternative(
      type: ProposalAlternativeType.splitBlock,
      label: label,
      description: description,
      part1: part1,
      part2: part2,
      previewCascade: previewCascade,
    );
  }

  factory ProposalAlternative.trimBuffer({
    required String label,
    required String description,
    required int compressedDurationMinutes,
    required DateTime proposedEndTime,
  }) {
    return ProposalAlternative(
      type: ProposalAlternativeType.trimBuffer,
      label: label,
      description: description,
      compressedDurationMinutes: compressedDurationMinutes,
      proposedEndTime: proposedEndTime,
    );
  }

  factory ProposalAlternative.alternativeSlot({
    required String label,
    required String description,
    required DateTime slotStartTime,
    required DateTime slotEndTime,
  }) {
    return ProposalAlternative(
      type: ProposalAlternativeType.alternativeSlot,
      label: label,
      description: description,
      slotStartTime: slotStartTime,
      slotEndTime: slotEndTime,
    );
  }
}

/// Conflict types when scheduling.
enum ConflictType {
  boundaryHalt, // Flexible task shifts into immovable Anchor boundary
  anchorClash,  // Direct anchor-to-anchor manual overlap clash
}

/// Represents a scheduling conflict.
@immutable
class ScheduleConflict {
  final ConflictType type;
  final CalendarEvent blockedEvent;
  final DateTime proposedStartTime;
  final CalendarEvent collidingAnchor;
  final int overlapMinutes;
  final List<ProposalAlternative> proposals;

  const ScheduleConflict({
    required this.type,
    required this.blockedEvent,
    required this.proposedStartTime,
    required this.collidingAnchor,
    required this.overlapMinutes,
    this.proposals = const [],
  });

  factory ScheduleConflict.boundaryHalt({
    required CalendarEvent blockedEvent,
    required DateTime proposedStartTime,
    required CalendarEvent collidingAnchor,
    required int overlapMinutes,
    required List<ProposalAlternative> proposals,
  }) {
    return ScheduleConflict(
      type: ConflictType.boundaryHalt,
      blockedEvent: blockedEvent,
      proposedStartTime: proposedStartTime,
      collidingAnchor: collidingAnchor,
      overlapMinutes: overlapMinutes,
      proposals: proposals,
    );
  }

  factory ScheduleConflict.anchorClash({
    required CalendarEvent blockedEvent,
    required DateTime proposedStartTime,
    required CalendarEvent collidingAnchor,
    required int overlapMinutes,
  }) {
    return ScheduleConflict(
      type: ConflictType.anchorClash,
      blockedEvent: blockedEvent,
      proposedStartTime: proposedStartTime,
      collidingAnchor: collidingAnchor,
      overlapMinutes: overlapMinutes,
      proposals: const [],
    );
  }
}

/// Outcome classification of a scheduling operation.
enum ScheduleResultType {
  clean,              // No downstream displacement needed
  cascaded,           // Flexible tasks cascaded cleanly
  haltedWithConflict, // Cascade halted at anchor or anchor clash occurred
}

/// Result returned by AutoCascadeScheduler.
@immutable
class ScheduleResult {
  final List<CalendarEvent> modifiedEvents;
  final List<ScheduleConflict> conflicts;
  final ScheduleResultType type;

  const ScheduleResult({
    required this.modifiedEvents,
    this.conflicts = const [],
    required this.type,
  });

  bool get hasConflicts => conflicts.isNotEmpty;
  bool get isSuccess => !hasConflicts;
}

/// Workload capacity status levels.
enum CapacityStatus {
  healthy,    // < 80% (< 6.4h of 8h)
  moderate,   // 80% - 100% (6.4h - 8.0h)
  overloaded, // > 100% (> 8.0h)
}

/// Workload capacity calculation for a specific day.
@immutable
class WorkloadCapacity {
  final DateTime date;
  final int capacityMinutes;          // Baseline capacity, default 480 minutes (8h)
  final int totalScheduledMinutes;    // Total minutes (Anchor + Flexible)
  final int anchorMinutes;            // Track 1
  final int flexibleMinutes;          // Track 2
  final double workloadPercentage;     // totalScheduledMinutes / capacityMinutes
  final CapacityStatus status;
  final int overageMinutes;           // max(0, totalScheduledMinutes - capacityMinutes)

  const WorkloadCapacity({
    required this.date,
    this.capacityMinutes = 480,
    required this.totalScheduledMinutes,
    required this.anchorMinutes,
    required this.flexibleMinutes,
    required this.workloadPercentage,
    required this.status,
    required this.overageMinutes,
  });

  bool get isOverloaded => status == CapacityStatus.overloaded;
  bool get isModerate => status == CapacityStatus.moderate;
  bool get isHealthy => status == CapacityStatus.healthy;

  /// Hours as formatted string (e.g. 5.5h)
  double get totalHours => totalScheduledMinutes / 60.0;
  double get capacityHours => capacityMinutes / 60.0;
}
