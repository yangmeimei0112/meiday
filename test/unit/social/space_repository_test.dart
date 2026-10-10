import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/space_repository_impl.dart';

void main() {
  group('SpaceRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late SpaceRepositoryImpl repository;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_spaces.db');
      database = AppDatabase(connection);
      repository = SpaceRepositoryImpl(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('ensureDefaultSpacesSeeded seeds 4 default spaces and enqueues outbox mutations', () async {
      final initial = await repository.getAllSpaces();
      expect(initial, isEmpty);

      await repository.ensureDefaultSpacesSeeded(userId: 'user_test_1');

      final seeded = await repository.getAllSpaces();
      expect(seeded.length, equals(4));

      final names = seeded.map((s) => s.name).toSet();
      expect(names, containsAll(['個人', '伴侶', '家庭', '工作']));

      final defaultSpace = await repository.getDefaultSpace();
      expect(defaultSpace, isNotNull);
      expect(defaultSpace!.name, equals('個人'));
      expect(defaultSpace.isDefault, isTrue);
      expect(defaultSpace.icon, equals('👤'));

      // Check sync_outbox mutations
      final outbox = await database.outboxDao.getPendingMutations();
      final spaceMutations = outbox.where((m) => m.targetTable == DbConstants.tableSpaces).toList();
      expect(spaceMutations.length, equals(4));
      expect(spaceMutations.every((m) => m.action == DbConstants.outboxActionInsert), isTrue);

      // Calling again is idempotent and does not duplicate
      await repository.ensureDefaultSpacesSeeded(userId: 'user_test_1');
      final afterSecond = await repository.getAllSpaces();
      expect(afterSecond.length, equals(4));
    });

    test('createSpace creates space with custom attributes and outbox record', () async {
      final created = await repository.createSpace(
        name: '讀書會',
        type: 'project',
        color: 0xFF10B981,
        icon: '📚',
        userId: 'user_test_1',
      );

      expect(created.name, equals('讀書會'));
      expect(created.icon, equals('📚'));
      expect(created.color, equals(0xFF10B981));

      final fetched = await repository.getSpaceById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('讀書會'));

      final outbox = await database.outboxDao.getPendingMutations();
      final createdMutation = outbox.firstWhere((m) => m.recordId == created.id);
      expect(createdMutation.action, equals(DbConstants.outboxActionInsert));
    });

    test('updateSpace updates attributes and enqueues UPDATE outbox mutation', () async {
      final space = await repository.createSpace(
        name: '跑步團',
        type: 'project',
        color: 0xFFF97316,
        icon: '🏃',
        userId: 'user_test_1',
      );

      final updated = space.copyWith(name: '馬拉松俱樂部', icon: '🏅');
      await repository.updateSpace(updated);

      final fetched = await repository.getSpaceById(space.id);
      expect(fetched!.name, equals('馬拉松俱樂部'));
      expect(fetched.icon, equals('🏅'));

      final outbox = await database.outboxDao.getPendingMutations();
      final updateMutation = outbox.firstWhere(
        (m) => m.recordId == space.id && m.action == DbConstants.outboxActionUpdate,
      );
      expect(updateMutation.payloadJson, contains('馬拉松俱樂部'));
    });

    test('deleteSpace soft-deletes space and excludes it from watch stream', () async {
      final space = await repository.createSpace(
        name: '已過期專案',
        type: 'project',
        color: 0xFF64748B,
        userId: 'user_test_1',
      );

      final beforeDelete = await repository.getAllSpaces();
      expect(beforeDelete.any((s) => s.id == space.id), isTrue);

      await repository.deleteSpace(space.id);

      final afterDelete = await repository.getAllSpaces();
      expect(afterDelete.any((s) => s.id == space.id), isFalse);

      final outbox = await database.outboxDao.getPendingMutations();
      final deleteMutation = outbox.firstWhere(
        (m) => m.recordId == space.id && m.action == DbConstants.outboxActionDelete,
      );
      expect(deleteMutation, isNotNull);
    });
  });
}
