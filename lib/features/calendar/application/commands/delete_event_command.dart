import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/uuid_utils.dart';
import 'calendar_command.dart';

class DeleteEventCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final String eventId;
  final AppDatabase database;
  final String userId;

  DeleteEventCommand({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.eventId,
    required this.database,
    required this.userId,
  });

  @override
  Future<void> execute() async {
    final now = DateTime.now();
    await database.transaction(() async {
      final existing = await database.eventDao.getEventById(eventId);
      if (existing == null) {
        throw DatabaseFailure('Event $eventId not found during DeleteEventCommand');
      }

      await (database.update(database.calendarEvents)..where((t) => t.id.equals(eventId))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: eventId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': eventId,
          'is_deleted': true,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> undo() async {
    final now = DateTime.now();
    await database.transaction(() async {
      await (database.update(database.calendarEvents)..where((t) => t.id.equals(eventId))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: eventId,
        action: DbConstants.outboxActionInsert,
        payloadJson: jsonEncode({
          'id': eventId,
          'is_deleted': false,
          'updated_at': now.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<void> redo() => execute();
}
