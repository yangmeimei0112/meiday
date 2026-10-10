import 'package:drift/drift.dart';

@DataClassName('EventChecklistData')
class EventChecklists extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get eventId => text().customConstraint('NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE')();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get assignedToUserId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
