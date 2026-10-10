// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_dao.dart';

// ignore_for_file: type=lint
mixin _$ChecklistDaoMixin on DatabaseAccessor<AppDatabase> {
  $CalendarEventsTable get calendarEvents => attachedDatabase.calendarEvents;
  $EventChecklistsTable get eventChecklists => attachedDatabase.eventChecklists;
  ChecklistDaoManager get managers => ChecklistDaoManager(this);
}

class ChecklistDaoManager {
  final _$ChecklistDaoMixin _db;
  ChecklistDaoManager(this._db);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(
          _db.attachedDatabase, _db.calendarEvents);
  $$EventChecklistsTableTableManager get eventChecklists =>
      $$EventChecklistsTableTableManager(
          _db.attachedDatabase, _db.eventChecklists);
}
