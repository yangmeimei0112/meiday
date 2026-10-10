import 'package:drift/drift.dart';

@DataClassName('PomodoroSessionData')
class PomodoroSessions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get eventId => text().nullable().customConstraint('NULL REFERENCES calendar_events(id) ON DELETE SET NULL')();
  TextColumn get userId => text()();
  IntColumn get durationMinutes => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get mode => text().withDefault(const Constant('pomodoro'))(); // pomodoro, short_break, long_break

  @override
  Set<Column> get primaryKey => {id};
}
