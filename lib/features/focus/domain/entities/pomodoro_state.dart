import 'package:meta/meta.dart';

enum PomodoroPhase {
  idle,
  focusing,
  shortBreak,
  longBreak,
  paused,
}

@immutable
class PomodoroState {
  final PomodoroPhase phase;
  final PomodoroPhase previousPhase;
  final int totalDurationSeconds;
  final int remainingSeconds;
  final String? activeEventId;
  final String? activeEventTitle;
  final String? activeSpaceId;
  final int completedCyclesCount;
  final DateTime? startedAt;
  final String? currentSessionId;

  const PomodoroState({
    this.phase = PomodoroPhase.idle,
    this.previousPhase = PomodoroPhase.idle,
    this.totalDurationSeconds = 1500, // 25 min default
    this.remainingSeconds = 1500,
    this.activeEventId,
    this.activeEventTitle,
    this.activeSpaceId,
    this.completedCyclesCount = 0,
    this.startedAt,
    this.currentSessionId,
  });

  bool get isIdle => phase == PomodoroPhase.idle;
  bool get isFocusing => phase == PomodoroPhase.focusing;
  bool get isBreak => phase == PomodoroPhase.shortBreak || phase == PomodoroPhase.longBreak;
  bool get isPaused => phase == PomodoroPhase.paused;

  double get progress {
    if (totalDurationSeconds <= 0) return 0.0;
    return ((totalDurationSeconds - remainingSeconds) / totalDurationSeconds).clamp(0.0, 1.0);
  }

  String get formattedTime {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PomodoroState copyWith({
    PomodoroPhase? phase,
    PomodoroPhase? previousPhase,
    int? totalDurationSeconds,
    int? remainingSeconds,
    String? activeEventId,
    String? activeEventTitle,
    String? activeSpaceId,
    int? completedCyclesCount,
    DateTime? startedAt,
    String? currentSessionId,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      previousPhase: previousPhase ?? this.previousPhase,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      activeEventId: activeEventId ?? this.activeEventId,
      activeEventTitle: activeEventTitle ?? this.activeEventTitle,
      activeSpaceId: activeSpaceId ?? this.activeSpaceId,
      completedCyclesCount: completedCyclesCount ?? this.completedCyclesCount,
      startedAt: startedAt ?? this.startedAt,
      currentSessionId: currentSessionId ?? this.currentSessionId,
    );
  }
}
