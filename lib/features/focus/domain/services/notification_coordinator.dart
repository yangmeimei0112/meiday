import '../../../../core/platform/audio_service.dart';
import '../../../../core/platform/notification_service.dart';
import '../entities/pomodoro_state.dart';

class NotificationCoordinator {
  final NotificationService notificationService;
  final AudioService audioService;
  bool isAppInForeground;
  final void Function(String message)? onInAppToast;

  static const String pomodoroCollapseId = 'chrono_pomodoro_timer';
  static const int pomodoroNotificationId = 9901;

  NotificationCoordinator({
    required this.notificationService,
    required this.audioService,
    this.isAppInForeground = true,
    this.onInAppToast,
  });

  /// Tier 1 & Tier 2 Coordination: Handles Pomodoro completion or phase changes
  Future<void> notifyFocusCompleted({
    required String title,
    required String body,
    String soundEffectPath = 'assets/audio/pomodoro_bell.mp3',
  }) async {
    if (isAppInForeground) {
      // Tier 1: In-App instant toast/banner & completion chime
      onInAppToast?.call('$title: $body');
      await audioService.playSoundEffect(soundEffectPath);
      // Online instant dismiss: cancel OS push to prevent tray clutter
      await notificationService.cancelByCollapseId(pomodoroCollapseId);
    } else {
      // Tier 2: System push notification with collapseId folding
      await notificationService.showNotification(
        id: pomodoroNotificationId,
        title: title,
        body: body,
        collapseId: pomodoroCollapseId,
      );
    }
  }

  /// Tier 2: Schedule background notification when app transitions to background
  Future<void> scheduleBackgroundTimerAlert({
    required int remainingSeconds,
    required String title,
    required String body,
  }) async {
    if (remainingSeconds <= 0) return;
    final scheduledTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    await notificationService.scheduleNotification(
      id: pomodoroNotificationId,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      collapseId: pomodoroCollapseId,
    );
  }

  /// Tier 3: App-Resume Batch Reconciliation
  /// When app resumes from background or tray:
  /// 1. Instantly purges stale pending alarms for this collapseId
  /// 2. Returns elapsed seconds for timer catching up
  Future<int> onAppResume({
    DateTime? now,
    PomodoroState? activeState,
  }) async {
    isAppInForeground = true;
    // Step 1: Online instant dismiss of background alarm
    await notificationService.cancelByCollapseId(pomodoroCollapseId);

    // Step 2: Time alignment
    if (activeState != null && activeState.startedAt != null && activeState.isFocusing) {
      final current = now ?? DateTime.now();
      final elapsed = current.difference(activeState.startedAt!).inSeconds;
      return elapsed;
    }
    return 0;
  }

  void onAppBackground() {
    isAppInForeground = false;
  }
}
