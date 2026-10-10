import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/uuid_utils.dart';
import 'calendar_command.dart';
import 'models/event_time_shift.dart';

class CascadeScheduleCommand implements CalendarCommand {
  @override
  final String id;
  @override
  final String description;
  @override
  final DateTime timestamp;

  final List<EventTimeShift> shifts;
  final AppDatabase database;
  final String userId;

  CascadeScheduleCommand({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.shifts,
    required this.database,
    required this.userId,
  });

  @override
  Future<void> execute() => _applyShifts(forward: true);

  @override
  Future<void> undo() => _applyShifts(forward: false);

  @override
  Future<void> redo() => _applyShifts(forward: true);

  Future<void> _applyShifts({required bool forward}) async {
    final now = DateTime.now();
    await database.transaction(() async {
      for (final shift in shifts) {
        final start = forward ? shift.targetStartTime : shift.previousStartTime;
        final end = forward ? shift.targetEndTime : shift.previousEndTime;

        final existing = await database.eventDao.getEventById(shift.eventId);
        if (existing == null) {
          throw DatabaseFailure('Event ${shift.eventId} not found during CascadeScheduleCommand');
        }

        final nextVersion = existing.version + 1;
        await (database.update(database.calendarEvents)..where((t) => t.id.equals(shift.eventId))).write(
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
          recordId: shift.eventId,
          action: DbConstants.outboxActionUpdate,
          payloadJson: jsonEncode({
            'id': shift.eventId,
            'user_id': userId,
            'start_time': start?.toIso8601String(),
            'end_time': end?.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'version': nextVersion,
          }),
        );
      }
    });
  }
}
