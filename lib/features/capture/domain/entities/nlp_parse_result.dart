import 'package:meta/meta.dart';
import 'nlp_token.dart';

@immutable
class NlpParseResult {
  final String rawInput;
  final String cleanTitle;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final bool isAllDay;
  final String? recurrenceRule; // RFC 5545 iCal RRULE
  final List<String> tags;
  final int priority; // 0: None, 1: Low, 2: Med, 3: High
  final double confidence; // 0.0 to 1.0
  final List<NlpToken> tokens;

  const NlpParseResult({
    required this.rawInput,
    required this.cleanTitle,
    this.startTime,
    this.endTime,
    this.durationMinutes = 30,
    this.isAllDay = false,
    this.recurrenceRule,
    this.tags = const [],
    this.priority = 0,
    this.confidence = 1.0,
    this.tokens = const [],
  });

  bool get hasTime => startTime != null;
  bool get hasDate => startTime != null || isAllDay;
  bool get hasRecurrence => recurrenceRule != null && recurrenceRule!.isNotEmpty;
  bool get isScheduled => startTime != null || isAllDay;

  NlpParseResult copyWith({
    String? rawInput,
    String? cleanTitle,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    bool? isAllDay,
    String? recurrenceRule,
    List<String>? tags,
    int? priority,
    double? confidence,
    List<NlpToken>? tokens,
  }) {
    return NlpParseResult(
      rawInput: rawInput ?? this.rawInput,
      cleanTitle: cleanTitle ?? this.cleanTitle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      confidence: confidence ?? this.confidence,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  String toString() {
    return 'NlpParseResult(title: "$cleanTitle", start: $startTime, end: $endTime, allDay: $isAllDay, rrule: $recurrenceRule, tags: $tags, priority: $priority)';
  }
}
