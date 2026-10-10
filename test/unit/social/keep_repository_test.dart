import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/keep_repository_impl.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/keep_item.dart';

void main() {
  group('KeepRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late KeepRepositoryImpl repository;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_keep.db');
      database = AppDatabase(connection);
      repository = KeepRepositoryImpl(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('createKeepItem stores item with tags and priority, enqueues Outbox mutation', () async {
      final now = DateTime.now();
      final item = KeepItem(
        id: UuidUtils.generate(),
        userId: 'u1',
        title: '看一本書《原子習慣》',
        notes: '重點在微小改變的複利效應',
        priority: KeepPriority.high,
        tags: const ['閱讀', '自我成長'],
        createdAt: now,
        updatedAt: now,
      );

      final created = await repository.createKeepItem(item);
      expect(created.title, equals('看一本書《原子習慣》'));

      final list = await repository.getActiveKeepItems('u1');
      expect(list.length, equals(1));
      expect(list.first.title, equals('看一本書《原子習慣》'));
      expect(list.first.notes, equals('重點在微小改變的複利效應'));
      expect(list.first.priority, equals(KeepPriority.high));
      expect(list.first.tags, containsAll(['閱讀', '自我成長']));

      final outbox = await database.outboxDao.getPendingMutations();
      final mutation = outbox.firstWhere(
        (m) => m.recordId == item.id && m.targetTable == DbConstants.tableKeepItems,
      );
      expect(mutation.action, equals(DbConstants.outboxActionInsert));
    });

    test('archiveKeepItem moves item to archived stream, unarchiveKeepItem restores it', () async {
      final now = DateTime.now();
      final item = KeepItem(
        id: UuidUtils.generate(),
        userId: 'u1',
        title: '整理衣櫃',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createKeepItem(item);
      expect((await repository.getActiveKeepItems('u1')).length, equals(1));

      // Archive item
      await repository.archiveKeepItem(item.id);
      expect((await repository.getActiveKeepItems('u1')), isEmpty);

      final archived = await repository.watchArchivedKeepItems('u1').first;
      expect(archived.length, equals(1));
      expect(archived.first.id, equals(item.id));
      expect(archived.first.isArchived, isTrue);

      // Unarchive item (e.g. on Undo)
      await repository.unarchiveKeepItem(item.id);
      expect((await repository.getActiveKeepItems('u1')).length, equals(1));
    });

    test('deleteKeepItem soft-deletes item and enqueues DELETE mutation', () async {
      final now = DateTime.now();
      final item = KeepItem(
        id: UuidUtils.generate(),
        userId: 'u1',
        title: '廢棄點子',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createKeepItem(item);
      await repository.deleteKeepItem(item.id);

      final list = await repository.getActiveKeepItems('u1');
      expect(list, isEmpty);

      final outbox = await database.outboxDao.getPendingMutations();
      final deleteMutation = outbox.firstWhere(
        (m) => m.recordId == item.id && m.action == DbConstants.outboxActionDelete,
      );
      expect(deleteMutation, isNotNull);
    });
  });
}
