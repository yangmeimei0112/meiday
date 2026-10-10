import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/application/commands/convert_keep_to_event_command.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/keep_repository_impl.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/space_repository_impl.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/keep_item.dart';

void main() {
  group('ConvertKeepToEventCommand Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late KeepRepositoryImpl keepRepository;
    late SpaceRepositoryImpl spaceRepository;
    late String defaultSpaceId;

    setUp(() async {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_convert_command.db');
      database = AppDatabase(connection);
      keepRepository = KeepRepositoryImpl(database: database);
      spaceRepository = SpaceRepositoryImpl(database: database);

      await spaceRepository.ensureDefaultSpacesSeeded(userId: 'u1');
      final defaultSpace = await spaceRepository.getDefaultSpace();
      defaultSpaceId = defaultSpace!.id;
    });

    tearDown(() async {
      await database.close();
    });

    test('execute converts Keep item to scheduled event, links space, archives item, and enqueues outbox', () async {
      final now = DateTime.now();
      final keepItem = KeepItem(
        id: UuidUtils.generate(),
        userId: 'u1',
        title: '整理季度預算表',
        notes: '包含雲端伺服器與行銷開支',
        priority: KeepPriority.high,
        createdAt: now,
        updatedAt: now,
      );
      await keepRepository.createKeepItem(keepItem);

      final startTime = DateTime(2026, 10, 10, 10, 0);
      final endTime = startTime.add(const Duration(minutes: 30));

      final cmd = ConvertKeepToEventCommand(
        id: UuidUtils.generate(),
        description: '排程「${keepItem.title}」',
        timestamp: DateTime.now(),
        keepItem: keepItem,
        targetStartTime: startTime,
        targetEndTime: endTime,
        targetSpaceId: defaultSpaceId,
        database: database,
        userId: 'u1',
      );

      await cmd.execute();

      // 1. Verify CalendarEvent exists
      final event = await database.eventDao.getEventById(cmd.createdEventId);
      expect(event, isNotNull);
      expect(event!.title, equals('整理季度預算表'));
      expect(event.description, equals('包含雲端伺服器與行銷開支'));
      expect(event.isAnchored, isFalse);
      expect(event.startTime, equals(startTime));
      expect(event.endTime, equals(endTime));

      // 2. Verify event_space_links row
      final links = await database.eventSpaceLinkDao.getSpaceIdsForEvent(cmd.createdEventId);
      expect(links, contains(defaultSpaceId));

      // 3. Verify Keep item archived with convertedToEventId
      final updatedKeep = await keepRepository.getKeepItemById(keepItem.id);
      expect(updatedKeep!.isArchived, isTrue);
      expect(updatedKeep.convertedToEventId, equals(cmd.createdEventId));

      // 4. Verify Outbox records (calendar_events, event_space_links, keep_items)
      final outbox = await database.outboxDao.getPendingMutations();
      expect(outbox.any((m) => m.targetTable == DbConstants.tableEvents && m.recordId == cmd.createdEventId), isTrue);
      expect(outbox.any((m) => m.targetTable == DbConstants.tableEventSpaceLinks && m.recordId == '${cmd.createdEventId}_$defaultSpaceId'), isTrue);
      expect(outbox.any((m) => m.targetTable == DbConstants.tableKeepItems && m.recordId == keepItem.id), isTrue);
    });

    test('undo cleanly rolls back event, unlinks space, restores Keep item', () async {
      final now = DateTime.now();
      final keepItem = KeepItem(
        id: UuidUtils.generate(),
        userId: 'u1',
        title: '洗車與吸塵',
        createdAt: now,
        updatedAt: now,
      );
      await keepRepository.createKeepItem(keepItem);

      final startTime = DateTime(2026, 10, 10, 14, 0);
      final endTime = startTime.add(const Duration(minutes: 30));

      final cmd = ConvertKeepToEventCommand(
        id: UuidUtils.generate(),
        description: '排程「${keepItem.title}」',
        timestamp: DateTime.now(),
        keepItem: keepItem,
        targetStartTime: startTime,
        targetEndTime: endTime,
        targetSpaceId: defaultSpaceId,
        database: database,
        userId: 'u1',
      );

      await cmd.execute();
      expect((await keepRepository.getActiveKeepItems('u1')), isEmpty);

      // Execute undo (Ctrl+Z)
      await cmd.undo();

      // 1. CalendarEvent is soft-deleted
      final event = await database.eventDao.getEventById(cmd.createdEventId);
      expect(event!.isDeleted, isTrue);

      // 2. Space link is removed and outbox delete mutation is queued
      final links = await database.eventSpaceLinkDao.getSpaceIdsForEvent(cmd.createdEventId);
      expect(links, isEmpty);
      final outboxAfterUndo = await database.outboxDao.getPendingMutations();
      expect(outboxAfterUndo.any((m) => m.targetTable == DbConstants.tableEventSpaceLinks && m.action == DbConstants.outboxActionDelete && m.recordId == '${cmd.createdEventId}_$defaultSpaceId'), isTrue);

      // 3. Keep item is un-archived and convertedToEventId is cleared
      final restoredKeep = await keepRepository.getKeepItemById(keepItem.id);
      expect(restoredKeep!.isArchived, isFalse);
      expect(restoredKeep.convertedToEventId, isNull);

      // 4. Appears back in active keep items
      final activeList = await keepRepository.getActiveKeepItems('u1');
      expect(activeList.length, equals(1));
      expect(activeList.first.id, equals(keepItem.id));

      // Test redo re-executes
      await cmd.redo();
      final redoneKeep = await keepRepository.getKeepItemById(keepItem.id);
      expect(redoneKeep!.isArchived, isTrue);
      expect(redoneKeep.convertedToEventId, equals(cmd.createdEventId));

      final redoneEvent = await database.eventDao.getEventById(cmd.createdEventId);
      expect(redoneEvent!.isDeleted, isFalse);

      final redoneLinks = await database.eventSpaceLinkDao.getSpaceIdsForEvent(cmd.createdEventId);
      expect(redoneLinks, contains(defaultSpaceId));
    });
  });
}
