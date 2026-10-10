import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/event_space_links_table.dart';
import '../tables/calendar_events_table.dart';

part 'event_space_link_dao.g.dart';

@DriftAccessor(tables: [EventSpaceLinks, CalendarEvents])
class EventSpaceLinkDao extends DatabaseAccessor<AppDatabase> with _$EventSpaceLinkDaoMixin {
  EventSpaceLinkDao(super.db);

  Stream<List<CalendarEventData>> watchEventsForSpace(String spaceId) {
    final query = select(calendarEvents).join([
      innerJoin(eventSpaceLinks, eventSpaceLinks.eventId.equalsExp(calendarEvents.id)),
    ])
      ..where(eventSpaceLinks.spaceId.equals(spaceId) & calendarEvents.isDeleted.equals(false))
      ..orderBy([OrderingTerm(expression: calendarEvents.startTime)]);

    return query.watch().map((rows) => rows.map((r) => r.readTable(calendarEvents)).toList());
  }

  Future<List<String>> getSpaceIdsForEvent(String eventId) async {
    final rows = await (select(eventSpaceLinks)..where((t) => t.eventId.equals(eventId))).get();
    return rows.map((r) => r.spaceId).toList();
  }

  Future<void> linkEventToSpaces(String eventId, List<String> spaceIds) async {
    await batch((b) {
      for (final spaceId in spaceIds) {
        b.insert(
          eventSpaceLinks,
          EventSpaceLinksCompanion.insert(
            id: '${eventId}_$spaceId',
            eventId: eventId,
            spaceId: spaceId,
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Stream<List<CalendarEventData>> watchEventsForSpaces(List<String> spaceIds) {
    if (spaceIds.isEmpty) {
      return Stream.value(<CalendarEventData>[]);
    }

    final query = select(calendarEvents, distinct: true).join([
      innerJoin(eventSpaceLinks, eventSpaceLinks.eventId.equalsExp(calendarEvents.id)),
    ])
      ..where(eventSpaceLinks.spaceId.isIn(spaceIds) & calendarEvents.isDeleted.equals(false))
      ..orderBy([OrderingTerm(expression: calendarEvents.startTime)]);

    return query.watch().map((rows) {
      final seenIds = <String>{};
      final uniqueEvents = <CalendarEventData>[];
      for (final r in rows) {
        final ev = r.readTable(calendarEvents);
        if (seenIds.add(ev.id)) {
          uniqueEvents.add(ev);
        }
      }
      return uniqueEvents;
    });
  }

  Stream<List<EventSpaceLinkData>> watchAllLinks() {
    return select(eventSpaceLinks).watch();
  }

  Future<List<EventSpaceLinkData>> getLinksForEvent(String eventId) {
    return (select(eventSpaceLinks)..where((t) => t.eventId.equals(eventId))).get();
  }

  Future<int> removeLink(String eventId, String spaceId) {
    return (delete(eventSpaceLinks)
          ..where((t) => t.eventId.equals(eventId) & t.spaceId.equals(spaceId)))
        .go();
  }
}
