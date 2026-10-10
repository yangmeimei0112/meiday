import 'dart:convert';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/event_checklist_item.dart';
import '../../domain/entities/grocery_category.dart';
import '../../domain/repositories/checklist_repository.dart';

class ChecklistRepositoryImpl implements ChecklistRepository {
  final AppDatabase database;

  ChecklistRepositoryImpl({required this.database});

  @override
  Stream<List<EventChecklistItem>> watchChecklist(String eventId) {
    return database.checklistDao.watchChecklistsForEvent(eventId).map(
          (rows) => rows.map(EventChecklistItem.fromData).toList(),
        );
  }

  @override
  Future<List<EventChecklistItem>> getChecklist(String eventId) async {
    final rows = await database.checklistDao.getChecklistsForEvent(eventId);
    return rows.map(EventChecklistItem.fromData).toList();
  }

  @override
  Future<EventChecklistItem> addItem({
    required String eventId,
    required String title,
    String? assignedToUserId,
    GroceryCategory? category,
    required String userId,
  }) async {
    final current = await getChecklist(eventId);
    final id = UuidUtils.generate();
    final now = DateTime.now();

    final effectiveCategory = category ?? GroceryCategoryClassifier.classify(title);

    final item = EventChecklistItem(
      id: id,
      eventId: eventId,
      title: title,
      isCompleted: false,
      assignedToUserId: assignedToUserId,
      sortOrder: current.length,
      groceryCategory: effectiveCategory,
      createdAt: now,
      updatedAt: now,
    );

    await database.transaction(() async {
      await database.checklistDao.insertItem(item.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventChecklists,
        recordId: id,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode(item.toJson()),
      );
    });

    return item;
  }

  @override
  Future<void> toggleItem({
    required String itemId,
    required bool isCompleted,
    required String userId,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.checklistDao.toggleCompleted(itemId, isCompleted);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventChecklists,
        recordId: itemId,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': itemId,
          'is_completed': isCompleted,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> reorderItems({
    required String eventId,
    required List<String> orderedItemIds,
    required String userId,
  }) async {
    final now = DateTime.now();
    final sortMap = <String, int>{};
    for (int i = 0; i < orderedItemIds.length; i++) {
      sortMap[orderedItemIds[i]] = i;
    }

    await database.transaction(() async {
      await database.checklistDao.batchUpdateSortOrders(sortMap);

      for (final entry in sortMap.entries) {
        await database.outboxDao.enqueueMutation(
          id: UuidUtils.generate(),
          tableName: DbConstants.tableEventChecklists,
          recordId: entry.key,
          action: DbConstants.outboxActionUpdate,
          payloadJson: jsonEncode({
            'id': entry.key,
            'sort_order': entry.value,
            'updated_at': now.toIso8601String(),
          }),
        );
      }
    });
  }

  @override
  Future<void> deleteItem({
    required String itemId,
    required String userId,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.checklistDao.deleteItem(itemId);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventChecklists,
        recordId: itemId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': itemId,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }
}
