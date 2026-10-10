import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/capture/application/bilingual_nlp_parser.dart';

void main() {
  group('BilingualNlpParser Comprehensive Tests', () {
    const parser = BilingualNlpParser();
    // Reference time: Monday, October 12, 2026, 09:00:00
    final ref = DateTime(2026, 10, 12, 9, 0, 0);

    test('1. Chinese relative date with afternoon time point', () {
      final res = parser.parse('明天下午3點開會', referenceTime: ref);
      expect(res.cleanTitle, equals('開會'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 15, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 13, 15, 30)));
      expect(res.isAllDay, isFalse);
    });

    test('2. English relative date with time and duration', () {
      final res = parser.parse('tomorrow at 3pm team meeting for 1.5h', referenceTime: ref);
      expect(res.cleanTitle, equals('team meeting'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 15, 0)));
      expect(res.durationMinutes, equals(90));
      expect(res.endTime, equals(DateTime(2026, 10, 13, 16, 30)));
      expect(res.isAllDay, isFalse);
    });

    test('3. Chinese time range extraction', () {
      final res = parser.parse('明天下午2點到3點半 專案討論', referenceTime: ref);
      expect(res.cleanTitle, equals('專案討論'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 14, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 13, 15, 30)));
      expect(res.durationMinutes, equals(90));
    });

    test('4. English time range extraction', () {
      final res = parser.parse('Friday 10am to 11:30am Sprint planning', referenceTime: ref);
      expect(res.cleanTitle, equals('Sprint planning'));
      // Friday of same week: Oct 12 (Mon) + 4 days = Oct 16
      expect(res.startTime, equals(DateTime(2026, 10, 16, 10, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 16, 11, 30)));
      expect(res.durationMinutes, equals(90));
    });

    test('5. Chinese compound duration variants', () {
      final res1 = parser.parse('寫程式 一個半小時', referenceTime: ref);
      expect(res1.durationMinutes, equals(90));

      final res2 = parser.parse('閱讀 兩小時半', referenceTime: ref);
      expect(res2.durationMinutes, equals(150));

      final res3 = parser.parse('運動 半小時', referenceTime: ref);
      expect(res3.durationMinutes, equals(30));

      final res4 = parser.parse('慢跑 45分鐘', referenceTime: ref);
      expect(res4.durationMinutes, equals(45));
    });

    test('6. Chinese weekly recurrence extraction (RRULE)', () {
      final res = parser.parse('每週三晚上8點 瑜珈課', referenceTime: ref);
      expect(res.cleanTitle, equals('瑜珈課'));
      expect(res.recurrenceRule, equals('RRULE:FREQ=WEEKLY;BYDAY=WE'));
      // Wednesday: Oct 12 + 2 days = Oct 14
      expect(res.startTime, equals(DateTime(2026, 10, 14, 20, 0)));
    });

    test('7. English weekly recurrence extraction', () {
      final res = parser.parse('every Monday at 9am standup', referenceTime: ref);
      expect(res.cleanTitle, equals('standup'));
      expect(res.recurrenceRule, equals('RRULE:FREQ=WEEKLY;BYDAY=MO'));
      expect(res.startTime, equals(DateTime(2026, 10, 19, 9, 0)));
    });

    test('8. Daily recurrence extraction in Chinese and English', () {
      final resZh = parser.parse('每天早上7點 晨跑', referenceTime: ref);
      expect(resZh.recurrenceRule, equals('RRULE:FREQ=DAILY'));
      expect(resZh.cleanTitle, equals('晨跑'));

      final resEn = parser.parse('daily meditation at 8am', referenceTime: ref);
      expect(resEn.recurrenceRule, equals('RRULE:FREQ=DAILY'));
      expect(resEn.cleanTitle, equals('meditation'));
    });

    test('9. Every weekday recurrence rule', () {
      final res = parser.parse('every weekday at 10am sync', referenceTime: ref);
      expect(res.recurrenceRule, equals('RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'));
      expect(res.cleanTitle, equals('sync'));
    });

    test('10. Next weekday delta math (subsequent week resolution)', () {
      // ref is Monday Oct 12. "next Wednesday" -> Oct 21 (+9 days)
      final res = parser.parse('next Wednesday at 2pm Client demo', referenceTime: ref);
      expect(res.cleanTitle, equals('Client demo'));
      expect(res.startTime, equals(DateTime(2026, 10, 21, 14, 0)));
    });

    test('11. Upcoming weekday in Chinese (this week)', () {
      // ref is Monday Oct 12. "週五" -> Oct 16 (+4 days)
      final res = parser.parse('週五下午3點 產品發布', referenceTime: ref);
      expect(res.cleanTitle, equals('產品發布'));
      expect(res.startTime, equals(DateTime(2026, 10, 16, 15, 0)));
    });

    test('12. Chinese absolute date and all-day inference', () {
      final res = parser.parse('10月20日 繳信用卡費', referenceTime: ref);
      expect(res.cleanTitle, equals('繳信用卡費'));
      expect(res.isAllDay, isTrue);
      expect(res.startTime, equals(DateTime(2026, 10, 20, 0, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 20, 23, 59, 59)));
    });

    test('13. All-day inference for relative date with no time tokens', () {
      final res = parser.parse('明天出差', referenceTime: ref);
      expect(res.cleanTitle, equals('出差'));
      expect(res.isAllDay, isTrue);
      expect(res.startTime, equals(DateTime(2026, 10, 13, 0, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 13, 23, 59, 59)));
    });

    test('14. Full-width punctuation normalization', () {
      final res = parser.parse('明天下午３點到５點：架構討論', referenceTime: ref);
      expect(res.cleanTitle, contains('架構討論'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 15, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 13, 17, 0)));
    });

    test('15. Tag extraction with hashtags', () {
      final res = parser.parse('審查財報 #工作 #急件 #財務', referenceTime: ref);
      expect(res.tags, equals(['工作', '急件', '財務']));
      expect(res.cleanTitle, equals('審查財報'));
    });

    test('16. Priority extraction (!1, !2, !3, !urgent, !緊急)', () {
      final res1 = parser.parse('修復關鍵崩潰 !1', referenceTime: ref);
      expect(res1.priority, equals(1));
      expect(res1.cleanTitle, equals('修復關鍵崩潰'));

      final res2 = parser.parse('緊急伺服器維護 !3', referenceTime: ref);
      expect(res2.priority, equals(3));

      final res3 = parser.parse('線上故障 !urgent', referenceTime: ref);
      expect(res3.priority, equals(3));
    });

    test('17. Pure unscheduled task with no date or time', () {
      final res = parser.parse('去超市買牛奶和吐司', referenceTime: ref);
      expect(res.cleanTitle, equals('去超市買牛奶和吐司'));
      expect(res.startTime, isNull);
      expect(res.endTime, isNull);
      expect(res.isAllDay, isFalse);
    });

    test('18. Midnight-crossing time range (11pm to 1am)', () {
      final res = parser.parse('明天 11pm to 1am 跨年狂歡派對', referenceTime: ref);
      expect(res.cleanTitle, equals('跨年狂歡派對'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 23, 0)));
      expect(res.endTime, equals(DateTime(2026, 10, 14, 1, 0)));
      expect(res.durationMinutes, equals(120));
    });

    test('19. Traditional Chinese numerals for hours and minutes', () {
      final res = parser.parse('明天下午兩點半 部門例會', referenceTime: ref);
      expect(res.cleanTitle, equals('部門例會'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 14, 30)));
    });

    test('20. 24-hour time point notation', () {
      final res = parser.parse('明天 14:30 線上代碼審查', referenceTime: ref);
      expect(res.cleanTitle, equals('線上代碼審查'));
      expect(res.startTime, equals(DateTime(2026, 10, 13, 14, 30)));
    });
  });
}
