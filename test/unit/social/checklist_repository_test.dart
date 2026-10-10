import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/constants/db_constants.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/data/repositories/checklist_repository_impl.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/event_checklist_item.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/grocery_category.dart';

void main() {
  group('ChecklistRepository Unit Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase database;
    late ChecklistRepositoryImpl repository;
    late String testEventId;

    setUp(() async {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_checklists.db');
      database = AppDatabase(connection);
      repository = ChecklistRepositoryImpl(database: database);

      testEventId = UuidUtils.generate();
      await database.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: testEventId,
          userId: 'u1',
          title: '超市採買清單活動',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('addItem saves item and enqueues Outbox mutation', () async {
      final item = await repository.addItem(
        eventId: testEventId,
        title: '鮮奶 2 瓶',
        userId: 'u1',
      );

      expect(item.title, equals('鮮奶 2 瓶'));
      expect(item.groceryCategory, equals(GroceryCategory.dairy));
      expect(item.isCompleted, isFalse);

      final list = await repository.getChecklist(testEventId);
      expect(list.length, equals(1));
      expect(list.first.id, equals(item.id));

      final outbox = await database.outboxDao.getPendingMutations();
      final mutation = outbox.firstWhere(
        (m) => m.recordId == item.id && m.targetTable == DbConstants.tableEventChecklists,
      );
      expect(mutation.action, equals(DbConstants.outboxActionInsert));
    });

    test('toggleItem updates completion status atomically', () async {
      final item = await repository.addItem(
        eventId: testEventId,
        title: '買蘋果',
        userId: 'u1',
      );

      expect(item.isCompleted, isFalse);

      await repository.toggleItem(itemId: item.id, isCompleted: true, userId: 'u1');

      final updated = await repository.getChecklist(testEventId);
      expect(updated.first.isCompleted, isTrue);

      final outbox = await database.outboxDao.getPendingMutations();
      final updateMutation = outbox.firstWhere(
        (m) => m.recordId == item.id && m.action == DbConstants.outboxActionUpdate,
      );
      expect(updateMutation.payloadJson, contains('"is_completed":true'));
    });

    test('reorderItems batches sort order updates', () async {
      final item1 = await repository.addItem(eventId: testEventId, title: 'Item 1', userId: 'u1');
      final item2 = await repository.addItem(eventId: testEventId, title: 'Item 2', userId: 'u1');
      final item3 = await repository.addItem(eventId: testEventId, title: 'Item 3', userId: 'u1');

      // Reorder: 3 -> 1 -> 2
      await repository.reorderItems(
        eventId: testEventId,
        orderedItemIds: [item3.id, item1.id, item2.id],
        userId: 'u1',
      );

      final list = await repository.getChecklist(testEventId);
      expect(list.map((i) => i.id).toList(), equals([item3.id, item1.id, item2.id]));
      expect(list[0].sortOrder, equals(0));
      expect(list[1].sortOrder, equals(1));
      expect(list[2].sortOrder, equals(2));
    });

    test('GroceryCategoryClassifier maps bilingual keywords accurately', () {
      expect(GroceryCategoryClassifier.classify('兩盒有機蘋果'), equals(GroceryCategory.produce));
      expect(GroceryCategoryClassifier.classify('Fresh Banana'), equals(GroceryCategory.produce));
      expect(GroceryCategoryClassifier.classify('全脂鮮奶 1L'), equals(GroceryCategory.dairy));
      expect(GroceryCategoryClassifier.classify('Organic Eggs'), equals(GroceryCategory.dairy));
      expect(GroceryCategoryClassifier.classify('澳洲牛排 2 塊'), equals(GroceryCategory.meat));
      expect(GroceryCategoryClassifier.classify('Chicken Breast'), equals(GroceryCategory.meat));
      expect(GroceryCategoryClassifier.classify('吐司一條'), equals(GroceryCategory.bakery));
      expect(GroceryCategoryClassifier.classify('特級初榨橄欖油'), equals(GroceryCategory.pantry));
      expect(GroceryCategoryClassifier.classify('三層衛生紙'), equals(GroceryCategory.household));
      expect(GroceryCategoryClassifier.classify('一般筆記本'), equals(GroceryCategory.other));
    });

    test('EventChecklistItem parses persisted category tag correctly', () {
      final dataWithTag = EventChecklistData(
        id: 'c1',
        eventId: 'e1',
        title: '[dairy] 鮮奶',
        isCompleted: false,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDeleted: false,
      );

      final entity = EventChecklistItem.fromData(dataWithTag);
      expect(entity.title, equals('鮮奶'));
      expect(entity.groceryCategory, equals(GroceryCategory.dairy));
      expect(entity.persistedTitle, equals('[dairy] 鮮奶'));
    });
  });
}
