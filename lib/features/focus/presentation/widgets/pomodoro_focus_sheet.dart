import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/pomodoro_state.dart';
import '../../domain/entities/soundscape_preset.dart';
import '../providers/focus_providers.dart';
import 'soundscape_drawer.dart';

class PomodoroFocusSheet extends ConsumerWidget {
  final String? eventId;
  final String? eventTitle;

  const PomodoroFocusSheet({
    super.key,
    this.eventId,
    this.eventTitle,
  });

  static Future<void> show(BuildContext context, {String? eventId, String? eventTitle}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PomodoroFocusSheet(eventId: eventId, eventTitle: eventTitle),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pomodoro = ref.watch(pomodoroControllerProvider);
    final controller = ref.read(pomodoroControllerProvider.notifier);
    final soundscape = ref.watch(soundscapeManagerProvider);

    final String phaseTitle;
    final Color phaseColor;
    switch (pomodoro.phase) {
      case PomodoroPhase.focusing:
        phaseTitle = '專注中 (Focus)';
        phaseColor = Colors.redAccent;
        break;
      case PomodoroPhase.shortBreak:
        phaseTitle = '短休息 (Short Break)';
        phaseColor = Colors.teal;
        break;
      case PomodoroPhase.longBreak:
        phaseTitle = '長休息 (Long Break)';
        phaseColor = Colors.blueAccent;
        break;
      case PomodoroPhase.paused:
        phaseTitle = '已暫停 (Paused)';
        phaseColor = Colors.orange;
        break;
      case PomodoroPhase.idle:
        phaseTitle = '準備專注 (Ready)';
        phaseColor = AppColors.primary;
        break;
    }

    final activeTitle = pomodoro.activeEventTitle ?? eventTitle ?? '自由專注 (Free Focus)';

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: phaseColor, width: 1),
                ),
                child: Text(
                  phaseTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: phaseColor,
                  ),
                ),
              ),
              const Spacer(),
              // Soundscape shortcut button
              IconButton(
                icon: Text(
                  soundscape.isPlaying
                      ? '${soundscape.currentPreset.emoji} 🎵'
                      : '🎧',
                  style: const TextStyle(fontSize: 16),
                ),
                tooltip: '環境音效',
                onPressed: () => SoundscapeDrawer.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Associated Task Title
          Text(
            activeTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Completed Pomodoro Count Tally
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('今日完成：', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                '🍅 x ${pomodoro.completedCyclesCount}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular Timer Display
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: pomodoro.progress,
                  strokeWidth: 8,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pomodoro.formattedTime,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pomodoro.isBreak ? '享受休息時光' : '專注當下',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pomodoro.isIdle) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('開始專注 (25m)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    controller.startFocus(
                      eventId: eventId,
                      eventTitle: eventTitle,
                      durationMinutes: 25,
                    );
                  },
                ),
              ] else ...[
                // Pause / Resume Button
                ElevatedButton.icon(
                  icon: Icon(pomodoro.isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(pomodoro.isPaused ? '繼續' : '暫停'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: phaseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (pomodoro.isPaused) {
                      controller.resume();
                    } else {
                      controller.pause();
                    }
                  },
                ),
                const SizedBox(width: 12),
                // Skip Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.skip_next),
                  label: const Text('跳過'),
                  onPressed: () => controller.skip(),
                ),
                const SizedBox(width: 12),
                // Stop Button
                TextButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('結束'),
                  onPressed: () => controller.stopOrInterrupt(reason: '使用者手動結束'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
