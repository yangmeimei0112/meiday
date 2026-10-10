import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/widget_service.dart';

void main() {
  group('WidgetSyncService (MockWidgetSyncService) tests', () {
    late MockWidgetSyncService widgetService;

    setUp(() {
      widgetService = MockWidgetSyncService();
    });

    test('updateTodaySnapshot stores and retrieves snapshot data', () async {
      expect(await widgetService.getCachedSnapshot(), isNull);

      final snapshot = {
        'date': '2026-10-09',
        'eventsCount': 3,
        'nextEvent': '專案週會 14:00',
      };
      await widgetService.updateTodaySnapshot(snapshot);

      final cached = await widgetService.getCachedSnapshot();
      expect(cached, isNotNull);
      expect(cached!['eventsCount'], equals(3));
      expect(cached['nextEvent'], equals('專案週會 14:00'));
    });

    test('refreshWidgets increments counter', () async {
      expect(widgetService.refreshCallCount, equals(0));
      await widgetService.refreshWidgets();
      await widgetService.refreshWidgets();
      expect(widgetService.refreshCallCount, equals(2));
    });

    test('clearSnapshot resets cached data', () async {
      await widgetService.updateTodaySnapshot({'test': 123});
      await widgetService.clearSnapshot();
      expect(await widgetService.getCachedSnapshot(), isNull);
    });
  });
}
