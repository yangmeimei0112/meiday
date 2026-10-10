import 'package:drift/drift.dart';

@DataClassName('EventCommentData')
class EventComments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get eventId => text().customConstraint('NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE')();
  TextColumn get userId => text()();
  TextColumn get authorName => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
