import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/audio_service.dart';
import 'package:smart_calendar_hub/core/platform/notification_service.dart';
import 'package:smart_calendar_hub/features/focus/domain/entities/pomodoro_state.dart';
import 'package:smart_calendar_hub/features/focus/domain/services/notification_coordinator.dart';

void main() {
  group('NotificationCoordinator 3-Tier Coordination Tests', () {
    late MockNotificationService mockNotifications;
    late MockAudioService mockAudio;
    late NotificationCoordinator coordinator;
    String? lastInAppToast;

    setUp(() {
      mockNotifications = MockNotificationService();
      mockAudio = MockAudioService();
      coordinator = NotificationCoordinator(
        notificationService: mockNotifications,
        audioService: mockAudio,
        isAppInForeground: true,
        onInAppToast: (msg) {
          lastInAppToast = msg;
        },
      );
    });

    test('1. Tier 1 (Foreground): Dispatches in-app toast, plays chime, suppresses OS push', () async {
      await coordinator.notifyFocusCompleted(
        title: '專注完成',
        body: '25分鐘專注已完成！',
      );

      // In-app toast was dispatched
      expect(lastInAppToast, contains('專注完成: 25分鐘專注已完成！'));
      // Chime was played
      expect(mockAudio.playedSoundEffects.length, greaterThan(0));
      // OS push was cancelled / suppressed with collapseId
      expect(mockNotifications.activeNotifications.isEmpty, isTrue);
    });

    test('2. Tier 2 (Background): Schedules system notification with collapseId folding', () async {
      coordinator.onAppBackground();

      await coordinator.notifyFocusCompleted(
        title: '番茄鐘完成',
        body: '請稍事休息 5 分鐘',
      );

      // Background OS notification was shown
      expect(mockNotifications.activeNotifications.length, equals(1));
      final notif = mockNotifications.activeNotifications.first;
      expect(notif.title, equals('番茄鐘完成'));
      expect(notif.collapseId, equals(NotificationCoordinator.pomodoroCollapseId));

      // Overwrite test (collapseId folding)
      await coordinator.notifyFocusCompleted(
        title: '休息結束',
        body: '開始下一個專注週期',
      );

      expect(mockNotifications.activeNotifications.length, equals(1));
      expect(mockNotifications.activeNotifications.first.title, equals('休息結束'));
    });

    test('3. Tier 3 (App-Resume Reconciliation): Clears stale alarms and synchronizes elapsed time', () async {
      coordinator.onAppBackground();
      await coordinator.scheduleBackgroundTimerAlert(
        remainingSeconds: 600,
        title: '提醒',
        body: '專注時間到',
      );

      expect(mockNotifications.scheduledNotifications.length, equals(1));

      // Simulate App Resume
      final startedAt = DateTime(2026, 10, 15, 10, 0, 0);
      final resumedAt = DateTime(2026, 10, 15, 10, 25, 0); // 25 minutes later
      final activeState = PomodoroState(
        phase: PomodoroPhase.focusing,
        startedAt: startedAt,
      );

      final elapsed = await coordinator.onAppResume(
        now: resumedAt,
        activeState: activeState,
      );

      // Pending notification cancelled
      expect(mockNotifications.scheduledNotifications.isEmpty, isTrue);
      // App foreground restored
      expect(coordinator.isAppInForeground, isTrue);
      // Synchronized 1500 seconds (25 minutes)
      expect(elapsed, equals(1500));
    });
  });
}
