import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/uuid_utils.dart';
import 'package:smart_calendar_hub/features/social/presentation/sheets/event_detail_sheet.dart';

void main() {
  group('EventDetailSheet Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;
    late String testEventId;

    setUp(() async {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_sheet.db');
      testDb = AppDatabase(connection);

      testEventId = UuidUtils.generate();
      await testDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: testEventId,
          userId: 'guest',
          title: '三折頁測試行程',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('EventDetailSheet renders 3 tabs and allows posting comments', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EventDetailSheet(
                eventId: testEventId,
                userId: 'guest',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify three tabs exist
      expect(find.text('討論留言'), findsOneWidget);
      expect(find.text('分工清單'), findsOneWidget);
      expect(find.text('相片附件'), findsOneWidget);

      // Tab 1: Post a comment
      final commentInput = find.byType(TextField);
      expect(commentInput, findsOneWidget);
      await tester.enterText(commentInput, '這是第一則留言討論！');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('這是第一則留言討論！'), findsOneWidget);

      // Switch to Tab 2: Checklist
      await tester.tap(find.text('分工清單'));
      await tester.pumpAndSettle();

      expect(find.text('待辦'), findsOneWidget);
      expect(find.text('🛒 採買'), findsOneWidget);

      // Add a checklist item
      final checklistInput = find.widgetWithText(TextField, '新增代辦任務...');
      expect(checklistInput, findsOneWidget);
      await tester.enterText(checklistInput, '買有機蘋果');
      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pumpAndSettle();

      expect(find.text('買有機蘋果'), findsOneWidget);

      // Switch to Tab 3: Attachments
      await tester.tap(find.text('相片附件'));
      await tester.pumpAndSettle();

      expect(find.text('相片清單'), findsOneWidget);
      expect(find.text('新增相片'), findsOneWidget);

      // Tap add photo
      await tester.tap(find.text('新增相片'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
