// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_dao.dart';

// ignore_for_file: type=lint
mixin _$SpaceDaoMixin on DatabaseAccessor<AppDatabase> {
  $CalendarSpacesTable get calendarSpaces => attachedDatabase.calendarSpaces;
  SpaceDaoManager get managers => SpaceDaoManager(this);
}

class SpaceDaoManager {
  final _$SpaceDaoMixin _db;
  SpaceDaoManager(this._db);
  $$CalendarSpacesTableTableManager get calendarSpaces =>
      $$CalendarSpacesTableTableManager(
          _db.attachedDatabase, _db.calendarSpaces);
}
