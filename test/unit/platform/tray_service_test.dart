import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/tray_service.dart';

void main() {
  group('TrayService (MockTrayService) tests', () {
    late MockTrayService tray;

    setUp(() {
      tray = MockTrayService();
    });

    test('initializeTray sets properties', () async {
      await tray.initializeTray(tooltip: 'ChronoHub - 桌面時間中樞');
      expect(tray.isInitialized, isTrue);
      expect(tray.currentTooltip, equals('ChronoHub - 桌面時間中樞'));
    });

    test('setBadge and setToolTip updates state', () async {
      await tray.setBadge(5);
      await tray.setToolTip('5 個待辦');
      expect(tray.currentBadgeCount, equals(5));
      expect(tray.currentTooltip, equals('5 個待辦'));
    });

    test('show, hide, and toggle mini calendar', () async {
      expect(await tray.isMiniCalendarVisible(), isFalse);

      await tray.showMiniCalendar();
      expect(await tray.isMiniCalendarVisible(), isTrue);

      await tray.hideMiniCalendar();
      expect(await tray.isMiniCalendarVisible(), isFalse);

      await tray.toggleMiniCalendar();
      expect(await tray.isMiniCalendarVisible(), isTrue);
    });

    test('tray events stream receives simulated events', () async {
      final events = <TrayEvent>[];
      final sub = tray.onTrayEvent.listen(events.add);

      tray.simulateTrayEvent(TrayEventType.click);
      tray.simulateTrayEvent(TrayEventType.doubleClick);

      await Future.delayed(Duration.zero);
      expect(events.length, equals(2));
      expect(events.first.type, equals(TrayEventType.click));
      expect(events.last.type, equals(TrayEventType.doubleClick));

      await sub.cancel();
    });

    test('destroyTray resets state', () async {
      await tray.initializeTray(tooltip: 'Tip');
      await tray.showMiniCalendar();
      await tray.setBadge(3);

      await tray.destroyTray();
      expect(tray.isInitialized, isFalse);
      expect(await tray.isMiniCalendarVisible(), isFalse);
      expect(tray.currentBadgeCount, equals(0));
    });
  });
}
