import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/pomodoro_session_dao.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../domain/entities/pomodoro_state.dart';

class PomodoroTimerController extends StateNotifier<PomodoroState> {
  final PomodoroSessionDao? sessionDao;
  final void Function(PomodoroState state)? onStateChanged;
  final void Function(String message)? onFocusCompleted;

  Timer? _periodicTimer;
  String _currentUserId = 'guest';
  String get currentUserId => _currentUserId;

  /// Serializes all persistence writes so ordering (insert → complete →
  /// actualMinutes accumulate) is deterministic.
  Future<void> _dbQueue = Future<void>.value();

  void _enqueueDb(Future<void> Function() op) {
    _dbQueue = _dbQueue.then((_) => op()).catchError((Object _) {});
  }

  /// Completes when all pending persistence writes have finished.
  Future<void> flush() => _dbQueue;

  PomodoroTimerController({
    this.sessionDao,
    this.onStateChanged,
    this.onFocusCompleted,
    PomodoroState initialState = const PomodoroState(),
  }) : super(initialState);

  void startFocus({
    String? eventId,
    String? eventTitle,
    String? spaceId,
    int durationMinutes = 25,
    String userId = 'guest',
  }) {
    _cancelTimer();
    _currentUserId = userId;
    final sessionId = UuidUtils.generate();
    final durationSeconds = durationMinutes * 60;
    final now = DateTime.now();

    state = state.copyWith(
      phase: PomodoroPhase.focusing,
      previousPhase: PomodoroPhase.idle,
      totalDurationSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
      activeEventId: eventId,
      activeEventTitle: eventTitle,
      activeSpaceId: spaceId,
      startedAt: now,
      currentSessionId: sessionId,
    );

    // Persist pending session
    if (sessionDao != null) {
      final dao = sessionDao!;
      _enqueueDb(() => dao.insertSession(
            PomodoroSessionsCompanion(
              id: drift.Value(sessionId),
              eventId: drift.Value(eventId),
              userId: drift.Value(userId),
              durationMinutes: drift.Value(durationMinutes),
              startedAt: drift.Value(now),
              completedAt: const drift.Value(null),
              mode: const drift.Value('pomodoro'),
            ),
          ));
    }

    onStateChanged?.call(state);
    _startTicker();
  }

  void pause() {
    if (state.phase != PomodoroPhase.focusing &&
        state.phase != PomodoroPhase.shortBreak &&
        state.phase != PomodoroPhase.longBreak) {
      return;
    }

    _cancelTimer();
    state = state.copyWith(
      phase: PomodoroPhase.paused,
      previousPhase: state.phase,
    );
    onStateChanged?.call(state);
  }

  void resume() {
    if (state.phase != PomodoroPhase.paused) return;

    state = state.copyWith(
      phase: state.previousPhase,
      previousPhase: PomodoroPhase.paused,
    );
    onStateChanged?.call(state);
    _startTicker();
  }

  void skip() {
    if (state.isFocusing) {
      _completeFocusPhase();
    } else if (state.isBreak) {
      _cancelTimer();
      state = state.copyWith(
        phase: PomodoroPhase.idle,
        previousPhase: state.phase,
        remainingSeconds: 1500,
        totalDurationSeconds: 1500,
      );
      onStateChanged?.call(state);
    }
  }

  void stopOrInterrupt({String? reason}) {
    _cancelTimer();
    if (state.isFocusing && state.currentSessionId != null && sessionDao != null) {
      final dao = sessionDao!;
      final sid = state.currentSessionId!;
      _enqueueDb(() => dao.recordInterrupt(sid));
    }

    state = state.copyWith(
      phase: PomodoroPhase.idle,
      previousPhase: state.phase,
      remainingSeconds: 1500,
      totalDurationSeconds: 1500,
      currentSessionId: null,
    );
    onStateChanged?.call(state);
  }

  void tick([int seconds = 1]) {
    if (state.phase == PomodoroPhase.idle || state.phase == PomodoroPhase.paused) {
      return;
    }

    final newRemaining = state.remainingSeconds - seconds;
    if (newRemaining <= 0) {
      if (state.isFocusing) {
        _completeFocusPhase();
      } else if (state.isBreak) {
        _cancelTimer();
        state = state.copyWith(
          phase: PomodoroPhase.idle,
          previousPhase: state.phase,
          remainingSeconds: 1500,
          totalDurationSeconds: 1500,
        );
        onStateChanged?.call(state);
      }
    } else {
      state = state.copyWith(remainingSeconds: newRemaining);
      onStateChanged?.call(state);
    }
  }

  void _completeFocusPhase() {
    _cancelTimer();
    final completedCycles = state.completedCyclesCount + 1;
    final isLongBreak = (completedCycles % 4 == 0);
    final breakPhase = isLongBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
    final breakSeconds = isLongBreak ? 900 : 300; // 15m or 5m
    final now = DateTime.now();

    // Persist completed session & update actual task focus minutes
    if (state.currentSessionId != null && sessionDao != null) {
      final dao = sessionDao!;
      final sid = state.currentSessionId!;
      final eid = state.activeEventId;
      final focusedMinutes = state.totalDurationSeconds ~/ 60;
      _enqueueDb(() async {
        await dao.completeSession(sid, now);
        if (eid != null) {
          await dao.addActualMinutesToEvent(eid, focusedMinutes);
        }
      });
    }

    onFocusCompleted?.call(
      '番茄鐘專注完成！進入${isLongBreak ? "長休息 (15分鐘)" : "短休息 (5分鐘)"}',
    );

    state = state.copyWith(
      phase: breakPhase,
      previousPhase: PomodoroPhase.focusing,
      completedCyclesCount: completedCycles,
      totalDurationSeconds: breakSeconds,
      remainingSeconds: breakSeconds,
      currentSessionId: null,
    );

    onStateChanged?.call(state);
    _startTicker();
  }

  void _startTicker() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick(1);
    });
  }

  void _cancelTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }
}
