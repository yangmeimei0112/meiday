import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/event_checklists_table.dart';

part 'checklist_dao.g.dart';

@DriftAccessor(tables: [EventChecklists])
class ChecklistDao extends DatabaseAccessor<AppDatabase> with _$ChecklistDaoMixin {
  ChecklistDao(super.db);

  Stream<List<EventChecklistData>> watchChecklistsForEvent(String eventId) {
    return (select(eventChecklists)
          ..where((t) => t.eventId.equals(eventId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  Future<int> insertItem(EventChecklistsCompanion companion) {
    return into(eventChecklists).insert(companion);
  }

  Future<int> insertChecklist(EventChecklistsCompanion companion) => insertItem(companion);

  Future<int> toggleCompleted(String id, bool completed) {
    return (update(eventChecklists)..where((t) => t.id.equals(id))).write(
      EventChecklistsCompanion(
        isCompleted: Value(completed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<EventChecklistData?> getItemById(String id) {
    return (select(eventChecklists)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<EventChecklistData>> getChecklistsForEvent(String eventId) {
    return (select(eventChecklists)
          ..where((t) => t.eventId.equals(eventId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<int> updateItemTitle(String id, String title) {
    return (update(eventChecklists)..where((t) => t.id.equals(id))).write(
      EventChecklistsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> batchUpdateSortOrders(Map<String, int> sortOrders) async {
    await batch((b) {
      for (final entry in sortOrders.entries) {
        b.update(
          eventChecklists,
          EventChecklistsCompanion(
            sortOrder: Value(entry.value),
            updatedAt: Value(DateTime.now()),
          ),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
  }

  Future<int> deleteItem(String id) {
    return (update(eventChecklists)..where((t) => t.id.equals(id))).write(
      EventChecklistsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
