import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/focus/application/pomodoro_timer_controller.dart';
import 'package:smart_calendar_hub/features/focus/domain/entities/pomodoro_state.dart';

void main() {
  late InMemoryDatabaseConnectionFactory connectionFactory;
  late AppDatabase database;
  late PomodoroTimerController controller;
  String? lastCompletionMessage;

  setUp(() async {
    connectionFactory = InMemoryDatabaseConnectionFactory();
    final connection = connectionFactory.createConnection('test_pomodoro.db');
    database = AppDatabase(connection);

    // Seed a calendar event for task binding test
    final now = DateTime.now();
    await database.into(database.calendarEvents).insert(
      CalendarEventsCompanion.insert(
        id: 'event-focus-1',
        userId: 'guest',
        title: '撰寫設計規格文件',
        createdAt: now,
        updatedAt: now,
      ),
    );

    controller = PomodoroTimerController(
      sessionDao: database.pomodoroSessionDao,
      onFocusCompleted: (msg) {
        lastCompletionMessage = msg;
      },
    );
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  group('PomodoroTimerController State Machine & Persistence', () {
    test('1. Initial state is idle with 25 minutes remaining', () {
      expect(controller.state.phase, equals(PomodoroPhase.idle));
      expect(controller.state.isIdle, isTrue);
      expect(controller.state.totalDurationSeconds, equals(1500));
      expect(controller.state.remainingSeconds, equals(1500));
      expect(controller.state.completedCyclesCount, equals(0));
      expect(controller.state.formattedTime, equals('25:00'));
    });

    test('2. startFocus transitions to focusing and binds active event', () {
      controller.startFocus(
        eventId: 'event-focus-1',
        eventTitle: '撰寫設計規格文件',
        durationMinutes: 25,
      );

      expect(controller.state.phase, equals(PomodoroPhase.focusing));
      expect(controller.state.isFocusing, isTrue);
      expect(controller.state.activeEventId, equals('event-focus-1'));
      expect(controller.state.activeEventTitle, equals('撰寫設計規格文件'));
      expect(controller.state.currentSessionId, isNotNull);
      expect(controller.state.startedAt, isNotNull);
    });

    test('3. Pause and Resume cycle transitions properly', () {
      controller.startFocus(durationMinutes: 25);
      expect(controller.state.phase, equals(PomodoroPhase.focusing));

      controller.pause();
      expect(controller.state.phase, equals(PomodoroPhase.paused));
      expect(controller.state.isPaused, isTrue);

      controller.resume();
      expect(controller.state.phase, equals(PomodoroPhase.focusing));
    });

    test('4. Ticking decrements remainingSeconds and updates progress', () {
      controller.startFocus(durationMinutes: 25);
      expect(controller.state.remainingSeconds, equals(1500));

      controller.tick(10);
      expect(controller.state.remainingSeconds, equals(1490));
      expect(controller.state.formattedTime, equals('24:50'));
      expect(controller.state.progress, closeTo(10 / 1500, 0.001));
    });

    test('5. Focus completion triggers short break, increments cycle, updates actualMinutes', () async {
      controller.startFocus(
        eventId: 'event-focus-1',
        eventTitle: '撰寫設計規格文件',
        durationMinutes: 25,
      );

      // Fast-forward tick to reach completion
      controller.tick(1500);

      expect(controller.state.phase, equals(PomodoroPhase.shortBreak));
      expect(controller.state.isBreak, isTrue);
      expect(controller.state.completedCyclesCount, equals(1));
      expect(controller.state.totalDurationSeconds, equals(300)); // 5 min short break
      expect(controller.state.remainingSeconds, equals(300));
      expect(lastCompletionMessage, contains('進入短休息'));

      // Verify database updated actualMinutes on target event!
      await controller.flush();
      final event = await (database.select(database.calendarEvents)
            ..where((t) => t.id.equals('event-focus-1')))
          .getSingle();
      expect(event.actualMinutes, equals(25));

      // Verify pomodoro session recorded in database
      final todayCount = await database.pomodoroSessionDao.getTodayCompletedPomodoroCount(DateTime.now());
      expect(todayCount, equals(1));
      final todayMinutes = await database.pomodoroSessionDao.getTodayCompletedFocusMinutes(DateTime.now());
      expect(todayMinutes, equals(25));
    });

    test('6. Completing 4 cycles switches to 15-minute long break', () {
      controller = PomodoroTimerController(
        sessionDao: database.pomodoroSessionDao,
        initialState: const PomodoroState(completedCyclesCount: 3),
      );

      controller.startFocus(durationMinutes: 25);
      controller.tick(1500);

      expect(controller.state.phase, equals(PomodoroPhase.longBreak));
      expect(controller.state.completedCyclesCount, equals(4));
      expect(controller.state.totalDurationSeconds, equals(900)); // 15 min long break
      expect(controller.state.remainingSeconds, equals(900));
    });

    test('7. Stop or Interrupt logs incomplete session to database', () async {
      controller.startFocus(
        eventId: 'event-focus-1',
        durationMinutes: 25,
      );
      final sessionId = controller.state.currentSessionId!;

      controller.stopOrInterrupt(reason: '電話打擾');
      expect(controller.state.phase, equals(PomodoroPhase.idle));
      expect(controller.state.remainingSeconds, equals(1500));

      // In database, session should have completedAt == null (interrupted)
      await controller.flush();
      final session = await (database.select(database.pomodoroSessions)
            ..where((t) => t.id.equals(sessionId)))
          .getSingle();
      expect(session.completedAt, isNull);
    });

    test('8. Skip transitions focus to break directly', () {
      controller.startFocus(durationMinutes: 25);
      controller.skip();

      expect(controller.state.phase, equals(PomodoroPhase.shortBreak));
      expect(controller.state.completedCyclesCount, equals(1));

      // Skip during break transitions back to idle
      controller.skip();
      expect(controller.state.phase, equals(PomodoroPhase.idle));
    });
  });
}
