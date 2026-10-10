import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../application/audio_soundscape_manager.dart';
import '../../application/pomodoro_timer_controller.dart';
import '../../domain/entities/pomodoro_state.dart';
import '../../domain/services/notification_coordinator.dart';

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((ref) {
  final notif = ref.watch(notificationServiceProvider);
  final audio = ref.watch(audioServiceProvider);
  return NotificationCoordinator(
    notificationService: notif,
    audioService: audio,
  );
});

final soundscapeManagerProvider = ChangeNotifierProvider<AudioSoundscapeManager>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return AudioSoundscapeManager(audioService: audio);
});

final pomodoroControllerProvider =
    StateNotifierProvider<PomodoroTimerController, PomodoroState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final soundscape = ref.watch(soundscapeManagerProvider.notifier);
  final coordinator = ref.watch(notificationCoordinatorProvider);

  final controller = PomodoroTimerController(
    sessionDao: db.pomodoroSessionDao,
    onStateChanged: (state) {
      soundscape.handlePomodoroStateChange(state);
    },
    onFocusCompleted: (msg) {
      coordinator.notifyFocusCompleted(title: '🍅 番茄鐘專注提醒', body: msg);
    },
  );
  return controller;
});

final todayFocusMinutesStreamProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  return db.pomodoroSessionDao.watchSessionsForDate(now).map((sessions) {
    return sessions
        .where((s) => s.completedAt != null && s.mode == 'pomodoro')
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
  });
});

final todayPomodoroCountStreamProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  return db.pomodoroSessionDao.watchSessionsForDate(now).map((sessions) {
    return sessions.where((s) => s.completedAt != null && s.mode == 'pomodoro').length;
  });
});
