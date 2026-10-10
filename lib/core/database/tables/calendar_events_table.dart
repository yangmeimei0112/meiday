import 'package:drift/drift.dart';

@DataClassName('CalendarEventData')
class CalendarEvents extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()(); // Creator user ID or 'guest'
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startTime => dateTime().nullable()(); // Null if unscheduled Keep task
  DateTimeColumn get endTime => dateTime().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  BoolColumn get isAnchored => boolean().withDefault(const Constant(false))(); // Track 1 vs Track 2
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, completed, cancelled
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 0: None, 1: Low, 2: Med, 3: High
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(30))();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();
  IntColumn get color => integer().nullable()(); // Nullable: inherits space color if null
  TextColumn get recurrenceRule => text().nullable()(); // iCal RRULE
  RealColumn get taskScore => real().withDefault(const Constant(0.0))(); // Dynamic GTD priority score
  IntColumn get version => integer().withDefault(const Constant(1))(); // Optimistic concurrency version
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
