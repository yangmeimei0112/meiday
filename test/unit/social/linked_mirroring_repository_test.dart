import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/linked_mirroring_repository_impl.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/space_repository_impl.dart';

void main() {
  group('LinkedMirroringRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late LinkedMirroringRepositoryImpl repository;
    late SpaceRepositoryImpl spaceRepository;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_mirroring.db');
      database = AppDatabase(connection);
      repository = LinkedMirroringRepositoryImpl(database: database);
      spaceRepository = SpaceRepositoryImpl(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('Zero data duplication: single event linked to multiple spaces appears once in distinct query', () async {
      final now = DateTime.now();
      final eventId = UuidUtils.generate();

      // Create two spaces
      final spacePersonal = await spaceRepository.createSpace(
        name: '個人',
        type: 'personal',
        color: 0xFF6366F1,
        userId: 'u1',
      );
      final spaceFamily = await spaceRepository.createSpace(
        name: '家庭',
        type: 'family',
        color: 0xFFF59E0B,
        userId: 'u1',
      );

      // Insert single event row in calendar_events
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: eventId,
          userId: 'u1',
          title: '家庭聚餐',
          startTime: Value(DateTime(2026, 10, 10, 18, 0)),
          endTime: Value(DateTime(2026, 10, 10, 20, 0)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Link event to both spaces
      await repository.linkEventToSpaces(
        eventId: eventId,
        spaceIds: [spacePersonal.id, spaceFamily.id],
        userId: 'u1',
      );

      // Verify zero data duplication: calendar_events has exactly 1 row
      final allEvents = await database.eventDao.watchAllEvents().first;
      expect(allEvents.length, equals(1));

      // Query for single space personal
      final personalEvents = await repository.watchEventsForSpaces([spacePersonal.id]).first;
      expect(personalEvents.length, equals(1));
      expect(personalEvents.first.title, equals('家庭聚餐'));

      // Query for single space family
      final familyEvents = await repository.watchEventsForSpaces([spaceFamily.id]).first;
      expect(familyEvents.length, equals(1));
      expect(familyEvents.first.title, equals('家庭聚餐'));

      // Query for BOTH spaces simultaneously: must be deduplicated via DISTINCT
      final combinedEvents = await repository.watchEventsForSpaces([spacePersonal.id, spaceFamily.id]).first;
      expect(combinedEvents.length, equals(1), reason: 'Linked event must appear exactly once on canvas');
    });

    test('Single source of truth: modifying event row updates all linked spaces instantly', () async {
      final now = DateTime.now();
      final eventId = UuidUtils.generate();

      final spaceA = await spaceRepository.createSpace(name: '空間A', type: 'project', color: 0xFF10B981, userId: 'u1');
      final spaceB = await spaceRepository.createSpace(name: '空間B', type: 'project', color: 0xFF8B5CF6, userId: 'u1');

      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: eventId,
          userId: 'u1',
          title: '初版標題',
          startTime: Value(DateTime(2026, 10, 10, 14, 0)),
          endTime: Value(DateTime(2026, 10, 10, 15, 0)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.linkEventToSpaces(eventId: eventId, spaceIds: [spaceA.id, spaceB.id], userId: 'u1');

      // Update event title in calendar_events
      await database.eventDao.updateEvent(
        CalendarEventsCompanion(
          id: Value(eventId),
          title: const Value('改動後的全域新標題'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final inSpaceA = await repository.watchEventsForSpaces([spaceA.id]).first;
      final inSpaceB = await repository.watchEventsForSpaces([spaceB.id]).first;

      expect(inSpaceA.first.title, equals('改動後的全域新標題'));
      expect(inSpaceB.first.title, equals('改動後的全域新標題'));
    });

    test('updateEventSpaceLinks reconciles differential links and queues outbox mutations', () async {
      final now = DateTime.now();
      final eventId = UuidUtils.generate();

      final space1 = await spaceRepository.createSpace(name: 'S1', type: 'project', color: 0xFF111111, userId: 'u1');
      final space2 = await spaceRepository.createSpace(name: 'S2', type: 'project', color: 0xFF222222, userId: 'u1');
      final space3 = await spaceRepository.createSpace(name: 'S3', type: 'project', color: 0xFF333333, userId: 'u1');

      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: eventId,
          userId: 'u1',
          title: '任務',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Initially link to S1 and S2
      await repository.linkEventToSpaces(eventId: eventId, spaceIds: [space1.id, space2.id], userId: 'u1');
      var links = await repository.getSpaceIdsForEvent(eventId);
      expect(links.toSet(), equals({space1.id, space2.id}));

      // Reconcile to S2 and S3 (removes S1, adds S3)
      await repository.updateEventSpaceLinks(
        eventId: eventId,
        targetSpaceIds: [space2.id, space3.id],
        userId: 'u1',
      );

      links = await repository.getSpaceIdsForEvent(eventId);
      expect(links.toSet(), equals({space2.id, space3.id}));

      // Check sync_outbox contains INSERT for S3 and DELETE for S1
      final outbox = await database.outboxDao.getPendingMutations();
      final linkMutations = outbox.where((m) => m.targetTable == DbConstants.tableEventSpaceLinks).toList();

      expect(linkMutations.any((m) => m.action == DbConstants.outboxActionInsert && m.recordId == '${eventId}_${space3.id}'), isTrue);
      expect(linkMutations.any((m) => m.action == DbConstants.outboxActionDelete && m.recordId == '${eventId}_${space1.id}'), isTrue);
    });

    test('watchEventToSpacesMap produces reactive mapping of eventId to linked spaces', () async {
      final now = DateTime.now();
      final eventId = UuidUtils.generate();

      final space = await spaceRepository.createSpace(name: '工作', type: 'project', color: 0xFF06B6D4, icon: '💼', userId: 'u1');

      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: eventId,
          userId: 'u1',
          title: '客戶發表',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.linkEventToSpaces(eventId: eventId, spaceIds: [space.id], userId: 'u1');

      final map = await repository.watchEventToSpacesMap().first;
      expect(map.containsKey(eventId), isTrue);
      expect(map[eventId]!.length, equals(1));
      expect(map[eventId]!.first.name, equals('工作'));
      expect(map[eventId]!.first.icon, equals('💼'));
    });
  });
}
