import 'dart:convert';
import 'package:drift/drift.dart' show Value, InsertMode;
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../../calendar/application/commands/calendar_command.dart';
import '../../domain/entities/keep_item.dart';

class ConvertKeepToEventCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final KeepItem keepItem;
  final DateTime targetStartTime;
  final DateTime targetEndTime;
  final String targetSpaceId;
  final AppDatabase database;
  final String userId;
  final String createdEventId;

  ConvertKeepToEventCommand({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.keepItem,
    required this.targetStartTime,
    required this.targetEndTime,
    required this.targetSpaceId,
    required this.database,
    required this.userId,
    String? createdEventId,
  }) : createdEventId = createdEventId ?? UuidUtils.generate();

  @override
  Future<void> execute() async {
    final now = DateTime.now();
    await database.transaction(() async {
      // 1. Insert newly scheduled CalendarEvent (using insertOrReplace for redo idempotency)
      await database.into(database.calendarEvents).insert(
        CalendarEventsCompanion.insert(
          id: createdEventId,
          userId: userId,
          title: keepItem.title,
          description: Value(keepItem.notes),
          startTime: Value(targetStartTime),
          endTime: Value(targetEndTime),
          isAnchored: const Value(false),
          color: Value(keepItem.color),
          priority: Value(keepItem.priority.value),
          createdAt: now,
          updatedAt: now,
          status: const Value('pending'),
          isDeleted: const Value(false),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 2. Link event to target space
      final linkUniqueKey = '${createdEventId}_$targetSpaceId';
      await database.into(database.eventSpaceLinks).insert(
        EventSpaceLinksCompanion.insert(
          id: linkUniqueKey,
          eventId: createdEventId,
          spaceId: targetSpaceId,
          createdAt: now,
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 3. Mark Keep item archived and set convertedToEventId
      await (database.update(database.keepItems)..where((t) => t.id.equals(keepItem.id))).write(
        KeepItemsCompanion(
          isArchived: const Value(true),
          convertedToEventId: Value(createdEventId),
          updatedAt: Value(now),
        ),
      );

      // 4. Record mutations in sync_outbox
      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: createdEventId,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode({
          'id': createdEventId,
          'user_id': userId,
          'title': keepItem.title,
          'start_time': targetStartTime.toIso8601String(),
          'end_time': targetEndTime.toIso8601String(),
          'is_anchored': false,
          'created_at': now.toIso8601String(),
        }),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventSpaceLinks,
        recordId: linkUniqueKey,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode({
          'id': linkUniqueKey,
          'event_id': createdEventId,
          'space_id': targetSpaceId,
          'created_at': now.toIso8601String(),
        }),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: keepItem.id,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': keepItem.id,
          'is_archived': true,
          'converted_to_event_id': createdEventId,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> undo() async {
    final now = DateTime.now();
    final linkUniqueKey = '${createdEventId}_$targetSpaceId';
    await database.transaction(() async {
      // 1. Soft-delete created event
      await database.eventDao.softDeleteEvent(createdEventId);

      // 2. Remove space link
      await database.eventSpaceLinkDao.removeLink(createdEventId, targetSpaceId);

      // 3. Un-archive Keep item and clear convertedToEventId
      await (database.update(database.keepItems)..where((t) => t.id.equals(keepItem.id))).write(
        KeepItemsCompanion(
          isArchived: const Value(false),
          convertedToEventId: const Value(null),
          updatedAt: Value(now),
        ),
      );

      // 4. Record mutations in sync_outbox
      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: createdEventId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': createdEventId,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventSpaceLinks,
        recordId: linkUniqueKey,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': linkUniqueKey,
          'event_id': createdEventId,
          'space_id': targetSpaceId,
          'is_deleted': true,
        }),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableKeepItems,
        recordId: keepItem.id,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': keepItem.id,
          'is_archived': false,
          'converted_to_event_id': null,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> redo() async {
    await execute();
  }
}
