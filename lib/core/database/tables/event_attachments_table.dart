import 'package:drift/drift.dart';

@DataClassName('EventAttachmentData')
class EventAttachments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get eventId => text().customConstraint('NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE')();
  TextColumn get userId => text()();
  TextColumn get fileName => text()();
  TextColumn get fileUrl => text()();
  TextColumn get fileType => text()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
