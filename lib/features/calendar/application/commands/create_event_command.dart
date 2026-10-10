import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import 'calendar_command.dart';

class CreateEventCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final CalendarEventsCompanion eventCompanion;
  final List<String> spaceIds;
  final AppDatabase database;
  final String userId;

  CreateEventCommand({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.eventCompanion,
    this.spaceIds = const [],
    required this.database,
    required this.userId,
  });

  @override
  Future<void> execute() async {
    final now = DateTime.now();
    await database.transaction(() async {
      await database.into(database.calendarEvents).insert(
            eventCompanion.copyWith(
              isDeleted: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );

      if (spaceIds.isNotEmpty) {
        await database.eventSpaceLinkDao.linkEventToSpaces(eventCompanion.id.value, spaceIds);
        for (final spId in spaceIds) {
          final linkUniqueKey = '${eventCompanion.id.value}_$spId';
          await database.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableEventSpaceLinks,
            recordId: linkUniqueKey,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': linkUniqueKey,
              'event_id': eventCompanion.id.value,
              'space_id': spId,
              'created_at': now.toIso8601String(),
            }),
          );
        }
      }

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: eventCompanion.id.value,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode({
          'id': eventCompanion.id.value,
          'user_id': userId,
          'title': eventCompanion.title.value,
          'start_time': eventCompanion.startTime.value?.toIso8601String(),
          'end_time': eventCompanion.endTime.value?.toIso8601String(),
          'is_anchored': eventCompanion.isAnchored.value,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> undo() async {
    final now = DateTime.now();
    await database.transaction(() async {
      await (database.update(database.calendarEvents)..where((t) => t.id.equals(eventCompanion.id.value))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: eventCompanion.id.value,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': eventCompanion.id.value,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> redo() async {
    final now = DateTime.now();
    await database.transaction(() async {
      await (database.update(database.calendarEvents)..where((t) => t.id.equals(eventCompanion.id.value))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: eventCompanion.id.value,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode({
          'id': eventCompanion.id.value,
          'is_deleted': false,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }
}
