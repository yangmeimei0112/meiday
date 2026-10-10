// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_dao.dart';

// ignore_for_file: type=lint
mixin _$CommentDaoMixin on DatabaseAccessor<AppDatabase> {
  $CalendarEventsTable get calendarEvents => attachedDatabase.calendarEvents;
  $EventCommentsTable get eventComments => attachedDatabase.eventComments;
  CommentDaoManager get managers => CommentDaoManager(this);
}

class CommentDaoManager {
  final _$CommentDaoMixin _db;
  CommentDaoManager(this._db);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(
          _db.attachedDatabase, _db.calendarEvents);
  $$EventCommentsTableTableManager get eventComments =>
      $$EventCommentsTableTableManager(_db.attachedDatabase, _db.eventComments);
}
