import 'package:flutter/foundation.dart';

@immutable
class BusyTimeSpan {
  final DateTime start;
  final DateTime end;
  final String? eventTitle; // Optional; hidden in privacy mode

  const BusyTimeSpan({
    required this.start,
    required this.end,
    this.eventTitle,
  });

  bool overlaps(DateTime slotStart, DateTime slotEnd) {
    return start.isBefore(slotEnd) && end.isAfter(slotStart);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusyTimeSpan &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          eventTitle == other.eventTitle;

  @override
  int get hashCode => Object.hash(start, end, eventTitle);
}

@immutable
class MemberSchedule {
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final int colorValue;
  final List<BusyTimeSpan> busySpans;

  const MemberSchedule({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.colorValue,
    required this.busySpans,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberSchedule &&
          runtimeType == other.runtimeType &&
          memberId == other.memberId;

  @override
  int get hashCode => memberId.hashCode;
}
