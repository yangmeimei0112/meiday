import 'dart:convert';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/keep_item.dart';
import '../../domain/repositories/keep_repository.dart';

class KeepRepositoryImpl implements KeepRepository {
  final AppDatabase database;

  KeepRepositoryImpl({required this.database});

  @override
  Stream<List<KeepItem>> watchActiveKeepItems(String userId) {
    return database.keepItemDao.watchActiveItems().map(
          (rows) => rows.map(KeepItem.fromData).toList(),
        );
  }

  @override
  Stream<List<KeepItem>> watchArchivedKeepItems(String userId) {
    return database.keepItemDao.watchArchivedItems().map(
          (rows) => rows.map(KeepItem.fromData).toList(),
        );
  }

  @override
  Future<List<KeepItem>> getActiveKeepItems(String userId) async {
    final rows = await database.keepItemDao.getActiveItems();
    return rows.map(KeepItem.fromData).toList();
  }

  @override
  Future<KeepItem?> getKeepItemById(String id) async {
    final row = await database.keepItemDao.getItemById(id);
    if (row == null) return null;
    return KeepItem.fromData(row);
  }

  @override
  Future<KeepItem> createKeepItem(KeepItem item) async {
    final now = DateTime.now();
    final effectiveItem = item.copyWith(
      createdAt: item.createdAt,
      updatedAt: now,
    );

    await database.transaction(() async {
      await database.keepItemDao.insertItem(effectiveItem.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: item.id,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode(effectiveItem.toJson()),
      );
    });

    return effectiveItem;
  }

  @override
  Future<void> updateKeepItem(KeepItem item) async {
    final now = DateTime.now();
    final updated = item.copyWith(updatedAt: now);

    await database.transaction(() async {
      await database.keepItemDao.updateItem(updated.toCompanion());

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: item.id,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode(updated.toJson()),
      );
    });
  }

  @override
  Future<void> archiveKeepItem(String id) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.keepItemDao.archiveItem(id);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: id,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': id,
          'is_archived': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> unarchiveKeepItem(String id) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.keepItemDao.unarchiveItem(id);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: id,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': id,
          'is_archived': false,
          'converted_to_event_id': null,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> deleteKeepItem(String id) async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.keepItemDao.deleteItem(id);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: id,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': id,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }
}
