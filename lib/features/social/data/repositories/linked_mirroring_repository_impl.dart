import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../../calendar/domain/entities/schedule_models.dart';
import '../../domain/entities/calendar_space.dart';
import '../../domain/repositories/linked_mirroring_repository.dart';

class LinkedMirroringRepositoryImpl implements LinkedMirroringRepository {
  final AppDatabase database;

  LinkedMirroringRepositoryImpl({required this.database});

  @override
  Stream<List<CalendarEvent>> watchEventsForSpaces(List<String> spaceIds) {
    return database.eventSpaceLinkDao.watchEventsForSpaces(spaceIds).map(
          (rows) => rows.map(CalendarEvent.fromData).toList(),
        );
  }

  @override
  Stream<List<String>> watchSpaceIdsForEvent(String eventId) {
    return (database.select(database.eventSpaceLinks)
          ..where((t) => t.eventId.equals(eventId)))
        .watch()
        .map((rows) => rows.map((r) => r.spaceId).toList());
  }

  @override
  Future<List<String>> getSpaceIdsForEvent(String eventId) {
    return database.eventSpaceLinkDao.getSpaceIdsForEvent(eventId);
  }

  @override
  Stream<Map<String, List<CalendarSpace>>> watchEventToSpacesMap() {
    // Combine links and spaces reactive streams
    final linksStream = database.eventSpaceLinkDao.watchAllLinks();

    return linksStream.asyncMap((links) async {
      final spaceRows = await (database.select(database.calendarSpaces)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final spacesById = {
        for (final s in spaceRows) s.id: CalendarSpace.fromData(s),
      };

      final map = <String, List<CalendarSpace>>{};
      for (final link in links) {
        final space = spacesById[link.spaceId];
        if (space != null) {
          map.putIfAbsent(link.eventId, () => []).add(space);
        }
      }
      return map;
    });
  }

  @override
  Future<void> linkEventToSpaces({
    required String eventId,
    required List<String> spaceIds,
    required String userId,
  }) async {
    final now = DateTime.now();
    await database.transaction(() async {
      for (final spaceId in spaceIds) {
        final linkId = '${eventId}_$spaceId';
        await database.into(database.eventSpaceLinks).insert(
              EventSpaceLinksCompanion.insert(
                id: linkId,
                eventId: eventId,
                spaceId: spaceId,
                createdAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );

        await database.outboxDao.enqueueMutation(
          id: UuidUtils.generate(),
          tableName: DbConstants.tableEventSpaceLinks,
          recordId: linkId,
          action: DbConstants.outboxActionInsert,
          payloadJson: jsonEncode({
            'id': linkId,
            'event_id': eventId,
            'space_id': spaceId,
            'created_at': now.toIso8601String(),
          }),
        );
      }
    });
  }

  @override
  Future<void> updateEventSpaceLinks({
    required String eventId,
    required List<String> targetSpaceIds,
    required String userId,
  }) async {
    final currentLinks = await database.eventSpaceLinkDao.getSpaceIdsForEvent(eventId);
    final currentSet = currentLinks.toSet();
    final targetSet = targetSpaceIds.toSet();

    final toAdd = targetSet.difference(currentSet);
    final toRemove = currentSet.difference(targetSet);

    if (toAdd.isEmpty && toRemove.isEmpty) return;

    final now = DateTime.now();
    await database.transaction(() async {
      for (final spaceId in toAdd) {
        final linkId = '${eventId}_$spaceId';
        await database.into(database.eventSpaceLinks).insert(
              EventSpaceLinksCompanion.insert(
                id: linkId,
                eventId: eventId,
                spaceId: spaceId,
                createdAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );

        await database.outboxDao.enqueueMutation(
          id: UuidUtils.generate(),
          tableName: DbConstants.tableEventSpaceLinks,
          recordId: linkId,
          action: DbConstants.outboxActionInsert,
          payloadJson: jsonEncode({
            'id': linkId,
            'event_id': eventId,
            'space_id': spaceId,
            'created_at': now.toIso8601String(),
          }),
        );
      }

      for (final spaceId in toRemove) {
        final linkId = '${eventId}_$spaceId';
        await database.eventSpaceLinkDao.removeLink(eventId, spaceId);

        await database.outboxDao.enqueueMutation(
          id: UuidUtils.generate(),
          tableName: DbConstants.tableEventSpaceLinks,
          recordId: linkId,
          action: DbConstants.outboxActionDelete,
          payloadJson: jsonEncode({
            'id': linkId,
            'event_id': eventId,
            'space_id': spaceId,
            'is_deleted': true,
          }),
        );
      }
    });
  }

  @override
  Future<void> unlinkEventFromSpace({
    required String eventId,
    required String spaceId,
    required String userId,
  }) async {
    final linkId = '${eventId}_$spaceId';
    await database.transaction(() async {
      await database.eventSpaceLinkDao.removeLink(eventId, spaceId);

      await database.outboxDao.enqueueMutation(
        id: UuidUtils.generate(),
        tableName: DbConstants.tableEventSpaceLinks,
        recordId: linkId,
        action: DbConstants.outboxActionDelete,
        payloadJson: jsonEncode({
          'id': linkId,
          'event_id': eventId,
          'space_id': spaceId,
          'is_deleted': true,
        }),
      );
    });
  }
}
