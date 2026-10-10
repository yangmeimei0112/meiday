import 'package:meta/meta.dart';

@immutable
class EventTimeShift {
  final String eventId;
  final String title;
  final DateTime? previousStartTime;
  final DateTime? previousEndTime;
  final DateTime? targetStartTime;
  final DateTime? targetEndTime;
  final int previousVersion;

  const EventTimeShift({
    required this.eventId,
    required this.title,
    required this.previousStartTime,
    required this.previousEndTime,
    required this.targetStartTime,
    required this.targetEndTime,
    this.previousVersion = 1,
  });

  @override
  String toString() =>
      'EventTimeShift(eventId: $eventId, $previousStartTime -> $targetStartTime)';
}
