import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/calendar_events_table.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [CalendarEvents])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  Stream<List<CalendarEventData>> watchAllEvents() {
    return (select(calendarEvents)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.startTime)]))
        .watch();
  }

  Stream<List<CalendarEventData>> watchEventsByRange(DateTime start, DateTime end) {
    return (select(calendarEvents)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.startTime.isBiggerOrEqualValue(start) &
              t.startTime.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.startTime)]))
        .watch();
  }

  Future<CalendarEventData?> getEventById(String id) {
    return (select(calendarEvents)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertEvent(CalendarEventsCompanion companion) {
    return into(calendarEvents).insert(companion);
  }

  Future<bool> updateEvent(CalendarEventsCompanion companion) {
    if (companion.id.present) {
      return (update(calendarEvents)..where((t) => t.id.equals(companion.id.value)))
          .write(companion)
          .then((count) => count > 0);
    }
    return update(calendarEvents).replace(companion);
  }

  Future<int> softDeleteEvent(String id) {
    return (update(calendarEvents)..where((t) => t.id.equals(id))).write(
      CalendarEventsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> hardDeleteEvent(String id) {
    return (delete(calendarEvents)..where((t) => t.id.equals(id))).go();
  }
}
