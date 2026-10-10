import 'package:drift/drift.dart';

@DataClassName('EventSpaceLinkData')
class EventSpaceLinks extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get eventId => text().customConstraint('NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE')();
  TextColumn get spaceId => text().customConstraint('NOT NULL REFERENCES calendar_spaces(id) ON DELETE CASCADE')();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {eventId, spaceId},
  ];
}
