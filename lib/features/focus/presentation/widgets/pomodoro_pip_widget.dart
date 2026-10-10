import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/focus_providers.dart';
import 'pomodoro_focus_sheet.dart';

class PomodoroPipWidget extends ConsumerWidget {
  const PomodoroPipWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoro = ref.watch(pomodoroControllerProvider);
    if (pomodoro.isIdle) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = ref.read(pomodoroControllerProvider.notifier);

    final Color badgeColor = pomodoro.isFocusing
        ? Colors.redAccent
        : (pomodoro.isBreak ? Colors.teal : Colors.orange);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PomodoroFocusSheet.show(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pomodoro.isBreak ? '☕' : '🍅',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                pomodoro.formattedTime,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (pomodoro.isPaused) {
                    controller.resume();
                  } else {
                    controller.pause();
                  }
                },
                child: Icon(
                  pomodoro.isPaused ? Icons.play_arrow : Icons.pause,
                  size: 16,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
