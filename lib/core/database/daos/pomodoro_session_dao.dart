import 'package:drift/drift.dart';
import '../app_database.dart';
class PomodoroSessionDao extends DatabaseAccessor<AppDatabase> {
  PomodoroSessionDao(super.db);

  $PomodoroSessionsTable get pomodoroSessions => attachedDatabase.pomodoroSessions;
  $CalendarEventsTable get calendarEvents => attachedDatabase.calendarEvents;

  Future<int> insertSession(PomodoroSessionsCompanion companion) async {
    if (companion.eventId.present && companion.eventId.value != null) {
      final exists = await (select(calendarEvents)
            ..where((t) => t.id.equals(companion.eventId.value!)))
          .getSingleOrNull();
      if (exists == null) {
        companion = companion.copyWith(eventId: const Value(null));
      }
    }
    return into(pomodoroSessions).insert(companion);
  }

  Future<bool> completeSession(String id, DateTime completedAt) {
    return (update(pomodoroSessions)..where((t) => t.id.equals(id)))
        .write(PomodoroSessionsCompanion(
          completedAt: Value(completedAt),
        ))
        .then((count) => count > 0);
  }

  Future<int> recordInterrupt(String id) {
    return (update(pomodoroSessions)..where((t) => t.id.equals(id)))
        .write(const PomodoroSessionsCompanion(
          completedAt: Value(null),
        ));
  }

  Stream<List<PomodoroSessionData>> watchSessionsForEvent(String eventId) {
    return (select(pomodoroSessions)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<PomodoroSessionData>> watchSessionsForDate(DateTime date, {String? userId}) {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    var query = select(pomodoroSessions)
      ..where((t) =>
          t.startedAt.isBiggerOrEqualValue(startOfDay) &
          t.startedAt.isSmallerOrEqualValue(endOfDay));
    if (userId != null) {
      query = query..where((t) => t.userId.equals(userId));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.startedAt)])).watch();
  }

  Future<int> getTodayCompletedFocusMinutes(DateTime today, {String? userId}) async {
    final sessions = await watchSessionsForDate(today, userId: userId).first;
    return sessions
        .where((s) => s.completedAt != null && s.mode == 'pomodoro')
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }

  Future<int> getTodayCompletedPomodoroCount(DateTime today, {String? userId}) async {
    final sessions = await watchSessionsForDate(today, userId: userId).first;
    return sessions.where((s) => s.completedAt != null && s.mode == 'pomodoro').length;
  }

  Future<void> addActualMinutesToEvent(String eventId, int minutes) async {
    final event = await (select(calendarEvents)..where((t) => t.id.equals(eventId))).getSingleOrNull();
    if (event != null) {
      final currentActual = event.actualMinutes;
      await (update(calendarEvents)..where((t) => t.id.equals(eventId))).write(
        CalendarEventsCompanion(
          actualMinutes: Value(currentActual + minutes),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
