import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/uuid_utils.dart';
import 'calendar_command.dart';

class MoveEventCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final String eventId;
  final DateTime? previousStartTime;
  final DateTime? previousEndTime;
  final DateTime? targetStartTime;
  final DateTime? targetEndTime;
  final AppDatabase database;
  final String userId;

  MoveEventCommand({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.eventId,
    required this.previousStartTime,
    required this.previousEndTime,
    required this.targetStartTime,
    required this.targetEndTime,
    required this.database,
    required this.userId,
  });

  @override
  Future<void> execute() => _apply(targetStartTime, targetEndTime);

  @override
  Future<void> undo() => _apply(previousStartTime, previousEndTime);

  @override
  Future<void> redo() => _apply(targetStartTime, targetEndTime);

  Future<void> _apply(DateTime? start, DateTime? end) async {
    final now = DateTime.now();
    await database.transaction(() async {
      final existing = await database.eventDao.getEventById(eventId);
      if (existing == null) {
        throw DatabaseFailure('Event $eventId not found during MoveEventCommand');
      }

      final nextVersion = existing.version + 1;
      await (database.update(database.calendarEvents)..where((t) => t.id.equals(eventId))).write(
        CalendarEventsCompanion(
          startTime: Value(start),
          endTime: Value(end),
          updatedAt: Value(now),
          version: Value(nextVersion),
        ),
      );

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEvents,
        recordId: eventId,
        action: DbConstants.outboxActionUpdate,
        payloadJson: jsonEncode({
          'id': eventId,
          'user_id': userId,
          'start_time': start?.toIso8601String(),
          'end_time': end?.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'version': nextVersion,
        }),
      );
    });
  }
}
