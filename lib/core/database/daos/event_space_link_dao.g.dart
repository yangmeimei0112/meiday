// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_space_link_dao.dart';

// ignore_for_file: type=lint
mixin _$EventSpaceLinkDaoMixin on DatabaseAccessor<AppDatabase> {
  $CalendarEventsTable get calendarEvents => attachedDatabase.calendarEvents;
  $CalendarSpacesTable get calendarSpaces => attachedDatabase.calendarSpaces;
  $EventSpaceLinksTable get eventSpaceLinks => attachedDatabase.eventSpaceLinks;
  EventSpaceLinkDaoManager get managers => EventSpaceLinkDaoManager(this);
}

class EventSpaceLinkDaoManager {
  final _$EventSpaceLinkDaoMixin _db;
  EventSpaceLinkDaoManager(this._db);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(
          _db.attachedDatabase, _db.calendarEvents);
  $$CalendarSpacesTableTableManager get calendarSpaces =>
      $$CalendarSpacesTableTableManager(
          _db.attachedDatabase, _db.calendarSpaces);
  $$EventSpaceLinksTableTableManager get eventSpaceLinks =>
      $$EventSpaceLinksTableTableManager(
          _db.attachedDatabase, _db.eventSpaceLinks);
}
