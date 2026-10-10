enum NlpTokenType {
  dateKeyword,     // today, tomorrow, 明天, 後天
  weekday,         // Monday, 週三, 禮拜五
  weekdayModifier, // next, this, 下週, 這週
  absoluteDate,    // 2026/10/15, 10月15日
  timePoint,       // 3pm, 14:30, 下午3點, 兩點半
  timeRange,       // 10am to 11:30am, 2點到3點半
  timeModifier,    // am, pm, 早上, 下午, 晚上
  duration,        // for 1h, 一小時, 30分鐘, 一個半小時
  recurrence,      // every Monday, 每天, 每週五
  allDay,          // all day, 整天, 全天
  tag,             // #工作, #personal
  priority,        // !high, !1, 緊急
  connector,       // at, for, 在, 於
}

class NlpToken {
  final NlpTokenType type;
  final String rawText;
  final int startOffset;
  final int endOffset;
  final dynamic parsedValue;

  const NlpToken({
    required this.type,
    required this.rawText,
    required this.startOffset,
    required this.endOffset,
    this.parsedValue,
  });

  @override
  String toString() => 'NlpToken($type, "$rawText", $startOffset..$endOffset)';
}
