import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/notification_service.dart';

void main() {
  group('NotificationService (MockNotificationService) tests', () {
    late MockNotificationService notifications;

    setUp(() {
      notifications = MockNotificationService();
    });

    test('initialize sets isInitialized', () async {
      expect(notifications.isInitialized, isFalse);
      await notifications.initialize();
      expect(notifications.isInitialized, isTrue);
    });

    test('showNotification adds to active notifications', () async {
      await notifications.showNotification(
        id: 1,
        title: '時間提醒',
        body: '會議即將開始',
      );
      expect(notifications.activeNotifications.length, equals(1));
      expect(notifications.activeNotifications.first.title, equals('時間提醒'));
    });

    test('scheduleNotification adds to scheduled notifications', () async {
      final scheduledTime = DateTime.now().add(const Duration(minutes: 15));
      await notifications.scheduleNotification(
        id: 2,
        title: '番茄鐘結束',
        body: '休息5分鐘',
        scheduledTime: scheduledTime,
      );
      expect(notifications.scheduledNotifications.length, equals(1));
      final pending = await notifications.getPendingNotifications();
      expect(pending.length, equals(1));
    });

    test('collapseId replaces prior notification (push folding)', () async {
      await notifications.showNotification(
        id: 10,
        title: '更新 1',
        body: '版本 1',
        collapseId: 'sync_channel',
      );
      await notifications.showNotification(
        id: 11,
        title: '更新 2',
        body: '版本 2',
        collapseId: 'sync_channel',
      );

      // Only the folded latest notification remains
      expect(notifications.activeNotifications.length, equals(1));
      expect(notifications.activeNotifications.first.id, equals(11));
      expect(notifications.activeNotifications.first.title, equals('更新 2'));
    });

    test('cancelByCollapseId removes matching notifications', () async {
      await notifications.showNotification(
        id: 20,
        title: 'T1',
        body: 'B1',
        collapseId: 'task_event',
      );
      await notifications.cancelByCollapseId('task_event');
      expect(notifications.activeNotifications.isEmpty, isTrue);
    });

    test('cancelAll clears active and scheduled', () async {
      await notifications.showNotification(id: 1, title: 'T', body: 'B');
      await notifications.scheduleNotification(
        id: 2,
        title: 'T',
        body: 'B',
        scheduledTime: DateTime.now(),
      );
      await notifications.cancelAll();
      expect(notifications.activeNotifications.isEmpty, isTrue);
      expect(notifications.scheduledNotifications.isEmpty, isTrue);
    });
  });
}
