import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/social/presentation/widgets/keep_item_card.dart';
import 'package:smart_calendar_hub/features/social/presentation/widgets/keep_pool_sidebar.dart';

void main() {
  group('KeepPoolSidebar Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_keep_widget.db');
      testDb = AppDatabase(connection);
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('KeepPoolSidebar renders header, quick-add input, and tip box', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool closed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: KeepPoolSidebar(
                userId: 'guest',
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('靈感池 (Keep)'), findsOneWidget);
      expect(find.text('💡 長按卡片拖拽至時間軸直接排程'), findsOneWidget);
      expect(find.text('靈感池目前是空的\n隨手記錄點子，隨時拖入日曆！'), findsOneWidget);

      // Verify close button calls callback
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('Adding new item creates KeepItemCard dynamically', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
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
          child: const MaterialApp(
            home: Scaffold(
              body: KeepPoolSidebar(userId: 'guest'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);

      await tester.enterText(input, '閱讀一本新書');
      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pumpAndSettle();

      expect(find.text('閱讀一本新書'), findsOneWidget);
      expect(find.byType(KeepItemCard), findsOneWidget);
    });
  });
}
