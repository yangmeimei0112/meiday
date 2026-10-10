import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/keep_items_table.dart';

part 'keep_item_dao.g.dart';

@DriftAccessor(tables: [KeepItems])
class KeepItemDao extends DatabaseAccessor<AppDatabase> with _$KeepItemDaoMixin {
  KeepItemDao(super.db);

  Stream<List<KeepItemData>> watchActiveItems() {
    return (select(keepItems)
          ..where((t) => t.isArchived.equals(false) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<KeepItemData>> watchArchivedItems() {
    return (select(keepItems)
          ..where((t) => t.isArchived.equals(true) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<KeepItemData>> watchAllKeepItems() => watchActiveItems();

  Future<KeepItemData?> getItemById(String id) {
    return (select(keepItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<KeepItemData>> getActiveItems() {
    return (select(keepItems)
          ..where((t) => t.isArchived.equals(false) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> insertItem(KeepItemsCompanion companion) {
    return into(keepItems).insert(companion);
  }

  Future<int> insertKeepItem(KeepItemsCompanion companion) => insertItem(companion);

  Future<bool> updateItem(KeepItemsCompanion companion) {
    return update(keepItems).replace(companion);
  }

  Future<int> archiveItem(String id) {
    return (update(keepItems)..where((t) => t.id.equals(id))).write(
      KeepItemsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> unarchiveItem(String id) {
    return (update(keepItems)..where((t) => t.id.equals(id))).write(
      KeepItemsCompanion(
        isArchived: const Value(false),
        convertedToEventId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> markConverted(String id, String eventId) {
    return (update(keepItems)..where((t) => t.id.equals(id))).write(
      KeepItemsCompanion(
        isArchived: const Value(true),
        convertedToEventId: Value(eventId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteItem(String id) {
    return (update(keepItems)..where((t) => t.id.equals(id))).write(
      KeepItemsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
