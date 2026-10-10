import '../domain/entities/nlp_parse_result.dart';
import '../domain/entities/nlp_token.dart';
import '../domain/services/nlp_parser.dart';

class BilingualNlpParser implements NlpParser {
  const BilingualNlpParser();

  @override
  NlpParseResult parse(String rawInput, {DateTime? referenceTime}) {
    if (rawInput.trim().isEmpty) {
      return NlpParseResult(
        rawInput: rawInput,
        cleanTitle: '',
        confidence: 0.0,
      );
    }

    final ref = referenceTime ?? DateTime.now();
    final tokens = <NlpToken>[];
    final matchedIntervals = <_Interval>[];

    // Stage 1: Normalize string for processing
    final normalized = _normalizePunctuation(rawInput);

    // Stage 2: Extract Tags and Priorities
    final tags = _extractTags(normalized, tokens, matchedIntervals);
    final priority = _extractPriority(normalized, tokens, matchedIntervals);

    // Stage 3: Extract Recurrence (RRULE)
    final recurrenceRule = _extractRecurrence(normalized, tokens, matchedIntervals);

    // Stage 4: Extract Duration
    final durationMinutes = _extractDuration(normalized, tokens, matchedIntervals);

    // Stage 5: Extract Time Range & Time Point
    final timeRangeResult = _extractTimeRange(normalized, tokens, matchedIntervals);
    final timePointResult = timeRangeResult == null
        ? _extractTimePoint(normalized, tokens, matchedIntervals)
        : null;

    // Stage 6: Extract Relative and Absolute Date
    final dateResult = _extractDate(normalized, ref, tokens, matchedIntervals);

    // Stage 7: Integrate Date & Time and determine all-day
    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;
    int finalDuration = durationMinutes ?? 30;

    if (dateResult != null) {
      if (timeRangeResult != null) {
        startTime = DateTime(
          dateResult.year,
          dateResult.month,
          dateResult.day,
          timeRangeResult.startHour,
          timeRangeResult.startMinute,
        );
        endTime = DateTime(
          dateResult.year,
          dateResult.month,
          dateResult.day,
          timeRangeResult.endHour,
          timeRangeResult.endMinute,
        );
        if (endTime.isBefore(startTime)) {
          // Range crosses midnight, e.g. 11pm to 1am
          endTime = endTime.add(const Duration(days: 1));
        }
        finalDuration = endTime.difference(startTime).inMinutes;
      } else if (timePointResult != null) {
        startTime = DateTime(
          dateResult.year,
          dateResult.month,
          dateResult.day,
          timePointResult.hour,
          timePointResult.minute,
        );
        endTime = startTime.add(Duration(minutes: finalDuration));
      } else {
        // Date only -> All-day event!
        isAllDay = true;
        startTime = DateTime(dateResult.year, dateResult.month, dateResult.day, 0, 0);
        endTime = DateTime(dateResult.year, dateResult.month, dateResult.day, 23, 59, 59);
      }
    } else {
      // No date token found
      if (timeRangeResult != null) {
        startTime = DateTime(
          ref.year,
          ref.month,
          ref.day,
          timeRangeResult.startHour,
          timeRangeResult.startMinute,
        );
        endTime = DateTime(
          ref.year,
          ref.month,
          ref.day,
          timeRangeResult.endHour,
          timeRangeResult.endMinute,
        );
        if (endTime.isBefore(startTime)) {
          endTime = endTime.add(const Duration(days: 1));
        }
        finalDuration = endTime.difference(startTime).inMinutes;
      } else if (timePointResult != null) {
        startTime = DateTime(
          ref.year,
          ref.month,
          ref.day,
          timePointResult.hour,
          timePointResult.minute,
        );
        endTime = startTime.add(Duration(minutes: finalDuration));
      }
    }

    // Stage 8: Extract Clean Title by removing matched intervals
    final cleanTitle = _extractCleanTitle(rawInput, matchedIntervals);

    return NlpParseResult(
      rawInput: rawInput,
      cleanTitle: cleanTitle.isNotEmpty ? cleanTitle : rawInput.trim(),
      startTime: startTime,
      endTime: endTime,
      durationMinutes: finalDuration,
      isAllDay: isAllDay,
      recurrenceRule: recurrenceRule,
      tags: tags,
      priority: priority,
      confidence: (startTime != null || isAllDay || cleanTitle.isNotEmpty) ? 1.0 : 0.5,
      tokens: tokens,
    );
  }

  // =========================================================================
  // NORMALIZATION
  // =========================================================================
  String _normalizePunctuation(String input) {
    var s = input
        .replaceAll('：', ':')
        .replaceAll('～', '~')
        .replaceAll('，', ',')
        .replaceAll('。', '.')
        .replaceAll('　', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    const fullDigits = '０１２３４５６７８９';
    const halfDigits = '0123456789';
    for (var i = 0; i < fullDigits.length; i++) {
      s = s.replaceAll(fullDigits[i], halfDigits[i]);
    }
    return s;
  }

  // =========================================================================
  // TAGS & PRIORITY
  // =========================================================================
  List<String> _extractTags(
    String input,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    final tags = <String>[];
    final reg = RegExp(r'#([^\s#]+)');
    for (final match in reg.allMatches(input)) {
      final tagText = match.group(1)!;
      tags.add(tagText);
      tokens.add(NlpToken(
        type: NlpTokenType.tag,
        rawText: match.group(0)!,
        startOffset: match.start,
        endOffset: match.end,
        parsedValue: tagText,
      ));
      intervals.add(_Interval(match.start, match.end));
    }
    return tags;
  }

  int _extractPriority(
    String input,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    final reg = RegExp(r'!(?:(\d)|(high|urgent|緊急))', caseSensitive: false);
    final match = reg.firstMatch(input);
    if (match != null) {
      int p = 1;
      if (match.group(1) != null) {
        p = int.tryParse(match.group(1)!) ?? 1;
      } else {
        p = 3;
      }
      p = p.clamp(1, 3);
      tokens.add(NlpToken(
        type: NlpTokenType.priority,
        rawText: match.group(0)!,
        startOffset: match.start,
        endOffset: match.end,
        parsedValue: p,
      ));
      intervals.add(_Interval(match.start, match.end));
      return p;
    }
    return 0;
  }

  // =========================================================================
  // RECURRENCE (RRULE)
  // =========================================================================
  String? _extractRecurrence(
    String input,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    // English rules
    final enWeekdayReg = RegExp(
      r'\b(?:every\s+(?:other\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun|weekday|day))\b',
      caseSensitive: false,
    );
    final enMatch = enWeekdayReg.firstMatch(input);
    if (enMatch != null) {
      final dayStr = enMatch.group(1)!.toLowerCase();
      intervals.add(_Interval(enMatch.start, enMatch.end));
      final String rrule;
      if (dayStr == 'day') {
        rrule = 'RRULE:FREQ=DAILY';
      } else if (dayStr == 'weekday') {
        rrule = 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
      } else {
        final code = _weekdayToIcalCode(dayStr);
        rrule = 'RRULE:FREQ=WEEKLY;BYDAY=$code';
      }
      tokens.add(NlpToken(
        type: NlpTokenType.recurrence,
        rawText: enMatch.group(0)!,
        startOffset: enMatch.start,
        endOffset: enMatch.end,
        parsedValue: rrule,
      ));
      return rrule;
    }

    if (RegExp(r'\b(?:daily|every\s+day)\b', caseSensitive: false).hasMatch(input)) {
      final m = RegExp(r'\b(?:daily|every\s+day)\b', caseSensitive: false).firstMatch(input)!;
      intervals.add(_Interval(m.start, m.end));
      return 'RRULE:FREQ=DAILY';
    }
    if (RegExp(r'\b(?:weekly|every\s+week)\b', caseSensitive: false).hasMatch(input)) {
      final m = RegExp(r'\b(?:weekly|every\s+week)\b', caseSensitive: false).firstMatch(input)!;
      intervals.add(_Interval(m.start, m.end));
      return 'RRULE:FREQ=WEEKLY';
    }
    if (RegExp(r'\b(?:monthly|every\s+month)\b', caseSensitive: false).hasMatch(input)) {
      final m = RegExp(r'\b(?:monthly|every\s+month)\b', caseSensitive: false).firstMatch(input)!;
      intervals.add(_Interval(m.start, m.end));
      return 'RRULE:FREQ=MONTHLY';
    }

    // Chinese rules
    final zhWeekdayReg = RegExp(r'(?:每週|每個星期|每星期|每禮拜)([一二三四五六日天])');
    final zhMatch = zhWeekdayReg.firstMatch(input);
    if (zhMatch != null) {
      intervals.add(_Interval(zhMatch.start, zhMatch.end));
      final code = _zhWeekdayToIcalCode(zhMatch.group(1)!);
      final rrule = 'RRULE:FREQ=WEEKLY;BYDAY=$code';
      tokens.add(NlpToken(
        type: NlpTokenType.recurrence,
        rawText: zhMatch.group(0)!,
        startOffset: zhMatch.start,
        endOffset: zhMatch.end,
        parsedValue: rrule,
      ));
      return rrule;
    }

    if (RegExp(r'(?:每天|每日)').hasMatch(input)) {
      final m = RegExp(r'(?:每天|每日)').firstMatch(input)!;
      intervals.add(_Interval(m.start, m.end));
      return 'RRULE:FREQ=DAILY';
    }
    if (RegExp(r'(?:每工作日|每個工作日)').hasMatch(input)) {
      final m = RegExp(r'(?:每工作日|每個工作日)').firstMatch(input)!;
      intervals.add(_Interval(m.start, m.end));
      return 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
    }
    if (RegExp(r'(?:每個月|每月)').hasMatch(input)) {
      final m = RegExp(r'(?:每個月|每月)').firstMatch(input)!;
      intervals.add(_Interval(m.start, m.end));
      return 'RRULE:FREQ=MONTHLY';
    }

    return null;
  }

  String _weekdayToIcalCode(String s) {
    if (s.startsWith('mo')) return 'MO';
    if (s.startsWith('tu')) return 'TU';
    if (s.startsWith('we')) return 'WE';
    if (s.startsWith('th')) return 'TH';
    if (s.startsWith('fr')) return 'FR';
    if (s.startsWith('sa')) return 'SA';
    if (s.startsWith('su')) return 'SU';
    return 'MO';
  }

  String _zhWeekdayToIcalCode(String s) {
    switch (s) {
      case '一': return 'MO';
      case '二': return 'TU';
      case '三': return 'WE';
      case '四': return 'TH';
      case '五': return 'FR';
      case '六': return 'SA';
      case '日':
      case '天': return 'SU';
      default: return 'MO';
    }
  }

  // =========================================================================
  // DURATION
  // =========================================================================
  int? _extractDuration(
    String input,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    // English duration, e.g. "for 1.5h", "for 45m", "for 2 hours", "for 30 mins"
    final enReg = RegExp(
      r'(?:for\s+)?(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b',
      caseSensitive: false,
    );
    for (final m in enReg.allMatches(input)) {
      final numVal = double.tryParse(m.group(1)!);
      if (numVal != null) {
        final unit = m.group(2)!.toLowerCase();
        int minutes = 0;
        if (unit.startsWith('h')) {
          minutes = (numVal * 60).round();
        } else {
          minutes = numVal.round();
        }
        intervals.add(_Interval(m.start, m.end));
        tokens.add(NlpToken(
          type: NlpTokenType.duration,
          rawText: m.group(0)!,
          startOffset: m.start,
          endOffset: m.end,
          parsedValue: minutes,
        ));
        return minutes;
      }
    }

    // Chinese compound durations:
    // "一個半小時", "兩小時半", "1.5小時", "半小時"
    final zhHourHalfReg = RegExp(r'([一二兩三四五六七八九十\d]+)個?小時半');
    final zhHourHalfMatch = zhHourHalfReg.firstMatch(input);
    if (zhHourHalfMatch != null) {
      final h = _parseZhInt(zhHourHalfMatch.group(1)!);
      final minutes = h * 60 + 30;
      intervals.add(_Interval(zhHourHalfMatch.start, zhHourHalfMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.duration,
        rawText: zhHourHalfMatch.group(0)!,
        startOffset: zhHourHalfMatch.start,
        endOffset: zhHourHalfMatch.end,
        parsedValue: minutes,
      ));
      return minutes;
    }

    final zhHourHalf2Reg = RegExp(r'([一二兩三四五六七八九十\d]+)個?半小時');
    final zhHourHalf2Match = zhHourHalf2Reg.firstMatch(input);
    if (zhHourHalf2Match != null) {
      final h = _parseZhInt(zhHourHalf2Match.group(1)!);
      final minutes = h * 60 + 30;
      intervals.add(_Interval(zhHourHalf2Match.start, zhHourHalf2Match.end));
      tokens.add(NlpToken(
        type: NlpTokenType.duration,
        rawText: zhHourHalf2Match.group(0)!,
        startOffset: zhHourHalf2Match.start,
        endOffset: zhHourHalf2Match.end,
        parsedValue: minutes,
      ));
      return minutes;
    }

    final zhHourReg = RegExp(r'([一二兩三四五六七八九十\d]+)個?小時');
    final zhHourMatch = zhHourReg.firstMatch(input);
    if (zhHourMatch != null) {
      final h = _parseZhInt(zhHourMatch.group(1)!);
      final minutes = h * 60;
      intervals.add(_Interval(zhHourMatch.start, zhHourMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.duration,
        rawText: zhHourMatch.group(0)!,
        startOffset: zhHourMatch.start,
        endOffset: zhHourMatch.end,
        parsedValue: minutes,
      ));
      return minutes;
    }

    final halfHourReg = RegExp(r'(?:半個?小時|半小時)');
    final halfHourMatch = halfHourReg.firstMatch(input);
    if (halfHourMatch != null) {
      intervals.add(_Interval(halfHourMatch.start, halfHourMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.duration,
        rawText: halfHourMatch.group(0)!,
        startOffset: halfHourMatch.start,
        endOffset: halfHourMatch.end,
        parsedValue: 30,
      ));
      return 30;
    }

    final zhMinReg = RegExp(r'([一二兩三四五六七八九十\d]+)分鐘');
    final zhMinMatch = zhMinReg.firstMatch(input);
    if (zhMinMatch != null) {
      final m = _parseZhInt(zhMinMatch.group(1)!);
      intervals.add(_Interval(zhMinMatch.start, zhMinMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.duration,
        rawText: zhMinMatch.group(0)!,
        startOffset: zhMinMatch.start,
        endOffset: zhMinMatch.end,
        parsedValue: m,
      ));
      return m;
    }

    return null;
  }

  // =========================================================================
  // TIME RANGE & TIME POINT
  // =========================================================================
  _TimeRange? _extractTimeRange(
    String input,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    // English range: "10am to 11:30am", "10:00 to 11:30", "14:00~15:30", "10am-12pm"
    final enRangeReg = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:to|-|~|至|到)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    );
    final enMatch = enRangeReg.firstMatch(input);
    if (enMatch != null) {
      final startH = int.tryParse(enMatch.group(1)!);
      final startM = int.tryParse(enMatch.group(2) ?? '0') ?? 0;
      final startMeridiem = enMatch.group(3)?.toLowerCase();

      final endH = int.tryParse(enMatch.group(4)!);
      final endM = int.tryParse(enMatch.group(5) ?? '0') ?? 0;
      final endMeridiem = enMatch.group(6)?.toLowerCase() ?? startMeridiem;

      if (startH != null && endH != null) {
        final realStartH = _adjustHourMeridiem(startH, startMeridiem ?? endMeridiem);
        final realEndH = _adjustHourMeridiem(endH, endMeridiem);
        intervals.add(_Interval(enMatch.start, enMatch.end));
        tokens.add(NlpToken(
          type: NlpTokenType.timeRange,
          rawText: enMatch.group(0)!,
          startOffset: enMatch.start,
          endOffset: enMatch.end,
          parsedValue: {'startHour': realStartH, 'endHour': realEndH},
        ));
        return _TimeRange(realStartH, startM, realEndH, endM);
      }
    }

    // Chinese range: "下午2點到3點半", "上午9點至10點", "下午2:00到3:30"
    final zhRangeReg = RegExp(
      r'(凌晨|半夜|早上|上午|早晨|中午|下午|午後|晚上|傍晚)?\s*([一二兩三四五六七八九十\d]+)(?:點|時)(?:(\d{1,2})分|(半))?\s*(?:到|至|~|-)\s*(凌晨|半夜|早上|上午|早晨|中午|下午|午後|晚上|傍晚)?\s*([一二兩三四五六七八九十\d]+)(?:點|時)(?:(\d{1,2})分|(半))?',
    );
    final zhMatch = zhRangeReg.firstMatch(input);
    if (zhMatch != null) {
      final startPeriod = zhMatch.group(1);
      final startHourRaw = _parseZhInt(zhMatch.group(2)!);
      final startMinuteRaw = zhMatch.group(4) != null
          ? 30
          : int.tryParse(zhMatch.group(3) ?? '0') ?? 0;

      final endPeriod = zhMatch.group(5) ?? startPeriod;
      final endHourRaw = _parseZhInt(zhMatch.group(6)!);
      final endMinuteRaw = zhMatch.group(8) != null
          ? 30
          : int.tryParse(zhMatch.group(7) ?? '0') ?? 0;

      final startH = _adjustZhPeriodHour(startHourRaw, startPeriod ?? endPeriod);
      final endH = _adjustZhPeriodHour(endHourRaw, endPeriod);

      intervals.add(_Interval(zhMatch.start, zhMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.timeRange,
        rawText: zhMatch.group(0)!,
        startOffset: zhMatch.start,
        endOffset: zhMatch.end,
        parsedValue: {'startHour': startH, 'endHour': endH},
      ));
      return _TimeRange(startH, startMinuteRaw, endH, endMinuteRaw);
    }

    return null;
  }

  _TimePoint? _extractTimePoint(
    String input,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    // English time point: "at 3pm", "at 14:30", "3:30pm", "10am"
    final enPointReg = RegExp(
      r'(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    );
    final enMatch = enPointReg.firstMatch(input);
    if (enMatch != null) {
      final h = int.parse(enMatch.group(1)!);
      final m = int.tryParse(enMatch.group(2) ?? '0') ?? 0;
      final meridiem = enMatch.group(3)!.toLowerCase();
      final adjustedH = _adjustHourMeridiem(h, meridiem);
      intervals.add(_Interval(enMatch.start, enMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.timePoint,
        rawText: enMatch.group(0)!,
        startOffset: enMatch.start,
        endOffset: enMatch.end,
        parsedValue: {'hour': adjustedH, 'minute': m},
      ));
      return _TimePoint(adjustedH, m);
    }

    // 24-hour time point: "14:30", "at 15:00"
    final en24Reg = RegExp(r'(?:at\s+)?\b([01]?\d|2[0-3]):([0-5]\d)\b');
    final en24Match = en24Reg.firstMatch(input);
    if (en24Match != null) {
      final h = int.parse(en24Match.group(1)!);
      final m = int.parse(en24Match.group(2)!);
      intervals.add(_Interval(en24Match.start, en24Match.end));
      tokens.add(NlpToken(
        type: NlpTokenType.timePoint,
        rawText: en24Match.group(0)!,
        startOffset: en24Match.start,
        endOffset: en24Match.end,
        parsedValue: {'hour': h, 'minute': m},
      ));
      return _TimePoint(h, m);
    }

    // Chinese time point: "下午3點半", "晚上8點", "早上9點15分", "下午兩點半", "3點"
    final zhPointReg = RegExp(
      r'(?:在|於)?\s*(凌晨|半夜|早上|上午|早晨|中午|下午|午後|晚上|傍晚)?\s*([一二兩三四五六七八九十\d]+)(?:點|時)(?:(\d{1,2})分|半)?',
    );
    final zhMatch = zhPointReg.firstMatch(input);
    if (zhMatch != null) {
      final period = zhMatch.group(1);
      final rawH = _parseZhInt(zhMatch.group(2)!);
      final rawM = zhMatch.group(0)!.contains('半')
          ? 30
          : int.tryParse(zhMatch.group(3) ?? '0') ?? 0;

      final finalH = _adjustZhPeriodHour(rawH, period);
      intervals.add(_Interval(zhMatch.start, zhMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.timePoint,
        rawText: zhMatch.group(0)!,
        startOffset: zhMatch.start,
        endOffset: zhMatch.end,
        parsedValue: {'hour': finalH, 'minute': rawM},
      ));
      return _TimePoint(finalH, rawM);
    }

    return null;
  }

  int _adjustHourMeridiem(int hour, String? meridiem) {
    if (meridiem == 'pm') {
      return hour < 12 ? hour + 12 : hour;
    } else if (meridiem == 'am') {
      return hour == 12 ? 0 : hour;
    }
    // Heuristic if no meridiem
    if (hour >= 1 && hour <= 7) return hour + 12; // 1..7 -> afternoon/evening
    return hour;
  }

  int _adjustZhPeriodHour(int hour, String? period) {
    if (period == null) {
      if (hour >= 1 && hour <= 6) return hour + 12;
      return hour;
    }
    if (period == '凌晨' || period == '半夜') {
      return hour == 12 ? 0 : hour;
    }
    if (period == '早上' || period == '上午' || period == '早晨') {
      return hour == 12 ? 0 : hour;
    }
    if (period == '中午') {
      if (hour == 12) return 12;
      if (hour < 6) return hour + 12;
      return hour;
    }
    if (period == '下午' || period == '午後' || period == '晚上' || period == '傍晚') {
      return hour < 12 ? hour + 12 : hour;
    }
    return hour;
  }

  // =========================================================================
  // DATE RESOLUTION
  // =========================================================================
  DateTime? _extractDate(
    String input,
    DateTime ref,
    List<NlpToken> tokens,
    List<_Interval> intervals,
  ) {
    // Relative keywords (Chinese & English) - Longer strings first to avoid substring collision
    const sortedEntries = <MapEntry<String, int>>[
      MapEntry('day after tomorrow', 2),
      MapEntry('yesterday', -1),
      MapEntry('tomorrow', 1),
      MapEntry('大後天', 3),
      MapEntry('today', 0),
      MapEntry('明天', 1),
      MapEntry('後天', 2),
      MapEntry('昨天', -1),
      MapEntry('今天', 0),
    ];

    for (final entry in sortedEntries) {
      final pattern = entry.key.contains(RegExp(r'[a-zA-Z]'))
          ? '\\b${entry.key}\\b'
          : entry.key;
      final reg = RegExp(pattern, caseSensitive: false);
      final m = reg.firstMatch(input);
      if (m != null) {
        final targetDate = ref.add(Duration(days: entry.value));
        intervals.add(_Interval(m.start, m.end));
        tokens.add(NlpToken(
          type: NlpTokenType.dateKeyword,
          rawText: m.group(0)!,
          startOffset: m.start,
          endOffset: m.end,
          parsedValue: targetDate,
        ));
        return targetDate;
      }
    }

    // Weekdays with "next" / "下週"
    // Formula: Δdays = (7 - refWeekday) + targetWeekday
    final nextZhReg = RegExp(r'(?:下週|下個星期|下星期|下禮拜)([一二三四五六日天])');
    final nextZhMatch = nextZhReg.firstMatch(input);
    if (nextZhMatch != null) {
      final targetWeekday = _zhWeekdayToInt(nextZhMatch.group(1)!);
      final delta = (7 - ref.weekday) + targetWeekday;
      final targetDate = ref.add(Duration(days: delta));
      intervals.add(_Interval(nextZhMatch.start, nextZhMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.weekday,
        rawText: nextZhMatch.group(0)!,
        startOffset: nextZhMatch.start,
        endOffset: nextZhMatch.end,
        parsedValue: targetDate,
      ));
      return targetDate;
    }

    final nextEnReg = RegExp(
      r'\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
      caseSensitive: false,
    );
    final nextEnMatch = nextEnReg.firstMatch(input);
    if (nextEnMatch != null) {
      final targetWeekday = _enWeekdayToInt(nextEnMatch.group(1)!);
      final delta = (7 - ref.weekday) + targetWeekday;
      final targetDate = ref.add(Duration(days: delta));
      intervals.add(_Interval(nextEnMatch.start, nextEnMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.weekday,
        rawText: nextEnMatch.group(0)!,
        startOffset: nextEnMatch.start,
        endOffset: nextEnMatch.end,
        parsedValue: targetDate,
      ));
      return targetDate;
    }

    // Upcoming weekdays: "週五", "禮拜三", "Friday", "this Wednesday"
    final thisZhReg = RegExp(r'(?:這週|本週|週|星期|禮拜)([一二三四五六日天])');
    final thisZhMatch = thisZhReg.firstMatch(input);
    if (thisZhMatch != null) {
      final targetWeekday = _zhWeekdayToInt(thisZhMatch.group(1)!);
      final int delta;
      if (targetWeekday > ref.weekday) {
        delta = targetWeekday - ref.weekday;
      } else {
        delta = 7 + (targetWeekday - ref.weekday);
      }
      final targetDate = ref.add(Duration(days: delta));
      intervals.add(_Interval(thisZhMatch.start, thisZhMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.weekday,
        rawText: thisZhMatch.group(0)!,
        startOffset: thisZhMatch.start,
        endOffset: thisZhMatch.end,
        parsedValue: targetDate,
      ));
      return targetDate;
    }

    final enWeekdayReg = RegExp(
      r'\b(?:this\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
      caseSensitive: false,
    );
    final enWeekdayMatch = enWeekdayReg.firstMatch(input);
    if (enWeekdayMatch != null) {
      final targetWeekday = _enWeekdayToInt(enWeekdayMatch.group(1)!);
      final int delta;
      if (targetWeekday > ref.weekday) {
        delta = targetWeekday - ref.weekday;
      } else {
        delta = 7 + (targetWeekday - ref.weekday);
      }
      final targetDate = ref.add(Duration(days: delta));
      intervals.add(_Interval(enWeekdayMatch.start, enWeekdayMatch.end));
      tokens.add(NlpToken(
        type: NlpTokenType.weekday,
        rawText: enWeekdayMatch.group(0)!,
        startOffset: enWeekdayMatch.start,
        endOffset: enWeekdayMatch.end,
        parsedValue: targetDate,
      ));
      return targetDate;
    }

    // Absolute date: YYYY-MM-DD or YYYY/MM/DD
    final fullDateReg = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    final fullDateMatch = fullDateReg.firstMatch(input);
    if (fullDateMatch != null) {
      final y = int.parse(fullDateMatch.group(1)!);
      final m = int.parse(fullDateMatch.group(2)!);
      final d = int.parse(fullDateMatch.group(3)!);
      intervals.add(_Interval(fullDateMatch.start, fullDateMatch.end));
      return DateTime(y, m, d);
    }

    // Absolute date: MM/DD or MM-DD
    final shortDateReg = RegExp(r'\b(\d{1,2})[-/](\d{1,2})\b');
    final shortDateMatch = shortDateReg.firstMatch(input);
    if (shortDateMatch != null) {
      final m = int.parse(shortDateMatch.group(1)!);
      final d = int.parse(shortDateMatch.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        intervals.add(_Interval(shortDateMatch.start, shortDateMatch.end));
        int year = ref.year;
        if (m < ref.month) year += 1;
        return DateTime(year, m, d);
      }
    }

    // Chinese absolute date: "10月15日", "5月20號"
    final zhAbsDateReg = RegExp(r'(\d{1,2})月(\d{1,2})[日號]');
    final zhAbsDateMatch = zhAbsDateReg.firstMatch(input);
    if (zhAbsDateMatch != null) {
      final m = int.parse(zhAbsDateMatch.group(1)!);
      final d = int.parse(zhAbsDateMatch.group(2)!);
      intervals.add(_Interval(zhAbsDateMatch.start, zhAbsDateMatch.end));
      int year = ref.year;
      if (m < ref.month) year += 1;
      return DateTime(year, m, d);
    }

    return null;
  }

  int _zhWeekdayToInt(String s) {
    switch (s) {
      case '一': return 1;
      case '二': return 2;
      case '三': return 3;
      case '四': return 4;
      case '五': return 5;
      case '六': return 6;
      case '日':
      case '天': return 7;
      default: return 1;
    }
  }

  int _enWeekdayToInt(String s) {
    final lower = s.toLowerCase();
    if (lower.startsWith('mo')) return 1;
    if (lower.startsWith('tu')) return 2;
    if (lower.startsWith('we')) return 3;
    if (lower.startsWith('th')) return 4;
    if (lower.startsWith('fr')) return 5;
    if (lower.startsWith('sa')) return 6;
    if (lower.startsWith('su')) return 7;
    return 1;
  }

  int _parseZhInt(String s) {
    final direct = int.tryParse(s);
    if (direct != null) return direct;
    switch (s) {
      case '零':
      case '〇': return 0;
      case '一': return 1;
      case '二':
      case '兩': return 2;
      case '三': return 3;
      case '四': return 4;
      case '五': return 5;
      case '六': return 6;
      case '七': return 7;
      case '八': return 8;
      case '九': return 9;
      case '十': return 10;
      case '十一': return 11;
      case '十二': return 12;
      case '十三': return 13;
      case '十四': return 14;
      case '十五': return 15;
      case '十六': return 16;
      case '十七': return 17;
      case '十八': return 18;
      case '十九': return 19;
      case '二十': return 20;
      case '二十一': return 21;
      case '二十二': return 22;
      case '二十三': return 23;
      case '二十四': return 24;
      case '三十': return 30;
      case '四十五': return 45;
      default: return 1;
    }
  }

  // =========================================================================
  // CLEAN TITLE EXTRACTION
  // =========================================================================
  String _extractCleanTitle(String raw, List<_Interval> intervals) {
    if (intervals.isEmpty) return raw.trim();

    // Sort intervals by start ascending
    intervals.sort((a, b) => a.start.compareTo(b.start));

    final sb = StringBuffer();
    int lastEnd = 0;
    for (final interval in intervals) {
      if (interval.start > lastEnd) {
        sb.write(raw.substring(lastEnd, interval.start));
      }
      if (interval.end > lastEnd) {
        lastEnd = interval.end;
      }
    }
    if (lastEnd < raw.length) {
      sb.write(raw.substring(lastEnd));
    }

    String result = sb.toString();
    // Strip connector words at boundaries
    result = result.replaceAll(RegExp(r'\b(?:at|on|for|to|in)\b', caseSensitive: false), ' ');
    result = result.replaceAll(RegExp(r'(?:^\s*|\s+)(?:在|於|從|到|至)(?:\s+|\s*$)'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }
}

class _Interval {
  final int start;
  final int end;
  _Interval(this.start, this.end);
}

class _TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  _TimeRange(this.startHour, this.startMinute, this.endHour, this.endMinute);
}

class _TimePoint {
  final int hour;
  final int minute;
  _TimePoint(this.hour, this.minute);
}
