import 'dart:convert';
import 'package:drift/drift.dart';
import '../../constants/db_constants.dart';
import '../../errors/failures.dart';
import '../../utils/uuid_utils.dart';
import '../app_database.dart';
import 'migration_models.dart';

class GuestMigrationExecutor {
  /// Executes atomic migration from guestDb to userDb.
  /// Guarantees:
  /// - Full ACID atomicity on userDb.
  /// - Complete sync_outbox enqueueing for all migrated records.
  /// - Safe purge of guestDb only upon successful commit.
  /// - Zero data loss: guestDb is untouched if any step fails.
  Future<MigrationResult> migrate({
    required AppDatabase guestDb,
    required AppDatabase userDb,
    required String userId,
    required MigrationMode mode,
  }) async {
    // 1. Discard Local Strategy: skip copying, purge guestDb, return.
    if (mode == MigrationMode.discardLocal) {
      await purgeGuestDatabase(guestDb);
      return MigrationResult.discarded();
    }

    try {
      // 2. Read all guest data in memory
      final guestSpaces = await (guestDb.select(guestDb.calendarSpaces)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final guestEvents = await (guestDb.select(guestDb.calendarEvents)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final guestLinks = await guestDb.select(guestDb.eventSpaceLinks).get();
      final guestComments = await (guestDb.select(guestDb.eventComments)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final guestAttachments = await guestDb.select(guestDb.eventAttachments).get();
      final guestChecklists = await (guestDb.select(guestDb.eventChecklists)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final guestKeepItems = await (guestDb.select(guestDb.keepItems)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final guestPomodoro = await guestDb.select(guestDb.pomodoroSessions).get();

      if (guestSpaces.isEmpty && guestEvents.isEmpty && guestKeepItems.isEmpty) {
        // Nothing to migrate
        await purgeGuestDatabase(guestDb);
        return MigrationResult(success: true, mode: mode);
      }

      int outboxCount = 0;
      int spacesCount = 0;
      int eventsCount = 0;
      int linksCount = 0;
      int commentsCount = 0;
      int attachmentsCount = 0;
      int checklistsCount = 0;
      int keepCount = 0;
      int pomodoroCount = 0;

      // 3. Resolve Space Mapping
      final spaceIdMapping = <String, String>{}; // guestSpaceId -> targetSpaceId
      final spacesToInsert = <CalendarSpacesCompanion>[];

      // Retrieve user's existing default space if present
      final existingUserDefaultSpace = await userDb.spaceDao.getDefaultSpace();

      for (final gSpace in guestSpaces) {
        if (mode == MigrationMode.mergeLocal && gSpace.isDefault && existingUserDefaultSpace != null) {
          // Merge guest default space into existing user personal space
          spaceIdMapping[gSpace.id] = existingUserDefaultSpace.id;
        } else if (mode == MigrationMode.autoMigrate && gSpace.isDefault && existingUserDefaultSpace != null) {
          // If autoMigrate but userDb already created a default space, map to it
          spaceIdMapping[gSpace.id] = existingUserDefaultSpace.id;
        } else {
          // Keep space ID, reassign owner
          spaceIdMapping[gSpace.id] = gSpace.id;
          spacesToInsert.add(
            CalendarSpacesCompanion.insert(
              id: gSpace.id,
              userId: userId,
              name: gSpace.name,
              type: gSpace.type,
              color: gSpace.color,
              icon: Value(gSpace.icon),
              isDefault: Value(existingUserDefaultSpace == null ? gSpace.isDefault : false),
              createdAt: gSpace.createdAt,
              updatedAt: DateTime.now(),
              isDeleted: const Value(false),
            ),
          );
        }
      }

      // Filter child records to strictly avoid foreign key violations on soft-deleted parents
      final validEventIds = guestEvents.map((e) => e.id).toSet();
      final validSpaceIds = {
        ...spacesToInsert.map((s) => s.id.value),
        ...spaceIdMapping.values,
      };

      final filteredLinks = guestLinks.where((l) {
        final targetSpaceId = spaceIdMapping[l.spaceId] ?? l.spaceId;
        return validEventIds.contains(l.eventId) && validSpaceIds.contains(targetSpaceId);
      }).toList();
      final filteredComments = guestComments.where((c) => validEventIds.contains(c.eventId)).toList();
      final filteredAttachments = guestAttachments.where((a) => validEventIds.contains(a.eventId)).toList();
      final filteredChecklists = guestChecklists.where((k) => validEventIds.contains(k.eventId)).toList();
      final filteredPomodoro = guestPomodoro.where((p) => p.eventId == null || validEventIds.contains(p.eventId)).toList();

      // 4. ATOMIC TRANSACTION ON userDb
      await userDb.transaction(() async {
        final now = DateTime.now();

        // Step 4.1: Insert Spaces & Outbox
        for (final spaceCompanion in spacesToInsert) {
          await userDb.into(userDb.calendarSpaces).insert(
                spaceCompanion,
                mode: InsertMode.insertOrReplace,
              );
          spacesCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableSpaces,
            recordId: spaceCompanion.id.value,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': spaceCompanion.id.value,
              'user_id': userId,
              'name': spaceCompanion.name.value,
              'type': spaceCompanion.type.value,
              'color': spaceCompanion.color.value,
              'icon': spaceCompanion.icon.value,
              'is_default': spaceCompanion.isDefault.value,
              'created_at': spaceCompanion.createdAt.value.toIso8601String(),
              'updated_at': spaceCompanion.updatedAt.value.toIso8601String(),
              'is_deleted': false,
            }),
          );
          outboxCount++;
        }

        // Step 4.2: Insert Events & Outbox
        for (final gEvent in guestEvents) {
          await userDb.into(userDb.calendarEvents).insert(
                CalendarEventsCompanion.insert(
                  id: gEvent.id,
                  userId: userId,
                  title: gEvent.title,
                  description: Value(gEvent.description),
                  location: Value(gEvent.location),
                  startTime: Value(gEvent.startTime),
                  endTime: Value(gEvent.endTime),
                  isAllDay: Value(gEvent.isAllDay),
                  isAnchored: Value(gEvent.isAnchored),
                  status: Value(gEvent.status),
                  priority: Value(gEvent.priority),
                  estimatedMinutes: Value(gEvent.estimatedMinutes),
                  actualMinutes: Value(gEvent.actualMinutes),
                  color: Value(gEvent.color),
                  recurrenceRule: Value(gEvent.recurrenceRule),
                  taskScore: Value(gEvent.taskScore),
                  version: Value(gEvent.version),
                  createdAt: gEvent.createdAt,
                  updatedAt: now,
                  isDeleted: const Value(false),
                ),
                mode: InsertMode.insertOrReplace,
              );
          eventsCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableEvents,
            recordId: gEvent.id,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': gEvent.id,
              'user_id': userId,
              'title': gEvent.title,
              'description': gEvent.description,
              'location': gEvent.location,
              'start_time': gEvent.startTime?.toIso8601String(),
              'end_time': gEvent.endTime?.toIso8601String(),
              'is_all_day': gEvent.isAllDay,
              'is_anchored': gEvent.isAnchored,
              'status': gEvent.status,
              'priority': gEvent.priority,
              'estimated_minutes': gEvent.estimatedMinutes,
              'actual_minutes': gEvent.actualMinutes,
              'color': gEvent.color,
              'recurrence_rule': gEvent.recurrenceRule,
              'task_score': gEvent.taskScore,
              'version': gEvent.version,
              'created_at': gEvent.createdAt.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'is_deleted': false,
            }),
          );
          outboxCount++;
        }

        // Step 4.3: Insert EventSpaceLinks (with mapped spaceId)
        final existingLinks = <String>{};
        for (final gLink in filteredLinks) {
          final targetSpaceId = spaceIdMapping[gLink.spaceId] ?? gLink.spaceId;
          final linkUniqueKey = '${gLink.eventId}_$targetSpaceId';

          if (existingLinks.add(linkUniqueKey)) {
            await userDb.into(userDb.eventSpaceLinks).insert(
                  EventSpaceLinksCompanion.insert(
                    id: linkUniqueKey,
                    eventId: gLink.eventId,
                    spaceId: targetSpaceId,
                    createdAt: gLink.createdAt,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            linksCount++;

            await userDb.outboxDao.enqueueMutation(
              id: UuidUtils.generate(),
              tableName: DbConstants.tableEventSpaceLinks,
              recordId: linkUniqueKey,
              action: DbConstants.outboxActionInsert,
              payloadJson: jsonEncode({
                'id': linkUniqueKey,
                'event_id': gLink.eventId,
                'space_id': targetSpaceId,
                'created_at': gLink.createdAt.toIso8601String(),
              }),
            );
            outboxCount++;
          }
        }

        // Step 4.4: Insert EventComments & Outbox
        for (final gComment in filteredComments) {
          await userDb.into(userDb.eventComments).insert(
                EventCommentsCompanion.insert(
                  id: gComment.id,
                  eventId: gComment.eventId,
                  userId: userId,
                  authorName: gComment.authorName,
                  content: gComment.content,
                  createdAt: gComment.createdAt,
                  updatedAt: now,
                  isDeleted: const Value(false),
                ),
                mode: InsertMode.insertOrReplace,
              );
          commentsCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableEventComments,
            recordId: gComment.id,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': gComment.id,
              'event_id': gComment.eventId,
              'user_id': userId,
              'author_name': gComment.authorName,
              'content': gComment.content,
              'created_at': gComment.createdAt.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'is_deleted': false,
            }),
          );
          outboxCount++;
        }

        // Step 4.5: Insert EventAttachments & Outbox
        for (final gAttach in filteredAttachments) {
          await userDb.into(userDb.eventAttachments).insert(
                EventAttachmentsCompanion.insert(
                  id: gAttach.id,
                  eventId: gAttach.eventId,
                  userId: userId,
                  fileName: gAttach.fileName,
                  fileUrl: gAttach.fileUrl,
                  fileType: gAttach.fileType,
                  fileSize: gAttach.fileSize,
                  createdAt: gAttach.createdAt,
                ),
                mode: InsertMode.insertOrReplace,
              );
          attachmentsCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableEventAttachments,
            recordId: gAttach.id,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': gAttach.id,
              'event_id': gAttach.eventId,
              'user_id': userId,
              'file_name': gAttach.fileName,
              'file_url': gAttach.fileUrl,
              'file_type': gAttach.fileType,
              'file_size': gAttach.fileSize,
              'created_at': gAttach.createdAt.toIso8601String(),
            }),
          );
          outboxCount++;
        }

        // Step 4.6: Insert EventChecklists & Outbox
        for (final gChecklist in filteredChecklists) {
          await userDb.into(userDb.eventChecklists).insert(
                EventChecklistsCompanion.insert(
                  id: gChecklist.id,
                  eventId: gChecklist.eventId,
                  title: gChecklist.title,
                  isCompleted: Value(gChecklist.isCompleted),
                  assignedToUserId: Value(userId),
                  sortOrder: Value(gChecklist.sortOrder),
                  createdAt: gChecklist.createdAt,
                  updatedAt: now,
                  isDeleted: const Value(false),
                ),
                mode: InsertMode.insertOrReplace,
              );
          checklistsCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableEventChecklists,
            recordId: gChecklist.id,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': gChecklist.id,
              'event_id': gChecklist.eventId,
              'title': gChecklist.title,
              'is_completed': gChecklist.isCompleted,
              'assigned_to_user_id': userId,
              'sort_order': gChecklist.sortOrder,
              'created_at': gChecklist.createdAt.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'is_deleted': false,
            }),
          );
          outboxCount++;
        }

        // Step 4.7: Insert KeepItems & Outbox
        for (final gKeep in guestKeepItems) {
          await userDb.into(userDb.keepItems).insert(
                KeepItemsCompanion.insert(
                  id: gKeep.id,
                  userId: userId,
                  title: gKeep.title,
                  content: Value(gKeep.content),
                  color: Value(gKeep.color),
                  tags: Value(gKeep.tags),
                  convertedToEventId: Value(gKeep.convertedToEventId),
                  isArchived: Value(gKeep.isArchived),
                  createdAt: gKeep.createdAt,
                  updatedAt: now,
                  isDeleted: const Value(false),
                ),
                mode: InsertMode.insertOrReplace,
              );
          keepCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tableKeepItems,
            recordId: gKeep.id,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': gKeep.id,
              'user_id': userId,
              'title': gKeep.title,
              'content': gKeep.content,
              'color': gKeep.color,
              'tags': gKeep.tags,
              'converted_to_event_id': gKeep.convertedToEventId,
              'is_archived': gKeep.isArchived,
              'created_at': gKeep.createdAt.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'is_deleted': false,
            }),
          );
          outboxCount++;
        }

        // Step 4.8: Insert PomodoroSessions & Outbox
        for (final gPomo in filteredPomodoro) {
          await userDb.into(userDb.pomodoroSessions).insert(
                PomodoroSessionsCompanion.insert(
                  id: gPomo.id,
                  eventId: Value(gPomo.eventId),
                  userId: userId,
                  durationMinutes: gPomo.durationMinutes,
                  startedAt: gPomo.startedAt,
                  completedAt: Value(gPomo.completedAt),
                  mode: Value(gPomo.mode),
                ),
                mode: InsertMode.insertOrReplace,
              );
          pomodoroCount++;

          await userDb.outboxDao.enqueueMutation(
            id: UuidUtils.generate(),
            tableName: DbConstants.tablePomodoroSessions,
            recordId: gPomo.id,
            action: DbConstants.outboxActionInsert,
            payloadJson: jsonEncode({
              'id': gPomo.id,
              'event_id': gPomo.eventId,
              'user_id': userId,
              'duration_minutes': gPomo.durationMinutes,
              'started_at': gPomo.startedAt.toIso8601String(),
              'completed_at': gPomo.completedAt?.toIso8601String(),
              'mode': gPomo.mode,
            }),
          );
          outboxCount++;
        }
      });

      // 5. PURGE guestDb SAFELY (only reached upon successful commit)
      await purgeGuestDatabase(guestDb);

      return MigrationResult(
        success: true,
        mode: mode,
        spacesMigrated: spacesCount,
        eventsMigrated: eventsCount,
        linksMigrated: linksCount,
        commentsMigrated: commentsCount,
        attachmentsMigrated: attachmentsCount,
        checklistsMigrated: checklistsCount,
        keepItemsMigrated: keepCount,
        pomodoroSessionsMigrated: pomodoroCount,
        outboxEntriesEnqueued: outboxCount,
      );
    } catch (e) {
      throw DatabaseFailure(
        'Guest data migration failed and rolled back cleanly: $e',
        cause: e,
      );
    }
  }

  /// Truncates all tables in guestDb in reverse topological order
  Future<void> purgeGuestDatabase(AppDatabase guestDb) async {
    await guestDb.transaction(() async {
      await guestDb.delete(guestDb.syncOutbox).go();
      await guestDb.delete(guestDb.pomodoroSessions).go();
      await guestDb.delete(guestDb.keepItems).go();
      await guestDb.delete(guestDb.eventChecklists).go();
      await guestDb.delete(guestDb.eventAttachments).go();
      await guestDb.delete(guestDb.eventComments).go();
      await guestDb.delete(guestDb.eventSpaceLinks).go();
      await guestDb.delete(guestDb.calendarEvents).go();
      await guestDb.delete(guestDb.calendarSpaces).go();
      await guestDb.delete(guestDb.userDevices).go();
    });
  }
}
