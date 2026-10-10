import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/capture/presentation/widgets/quick_capture_modal.dart';

void main() {
  group('QuickCaptureModal Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_modal.db');
      testDb = AppDatabase(connection);
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('Renders input field and real-time chips upon typing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuickCaptureModal(),
            ),
          ),
        ),
      );

      expect(find.text('NLP 智慧速記 (Quick Capture)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Enter input text
      await tester.enterText(find.byType(TextField), '明天下午3點開會 #工作 !1');
      await tester.pumpAndSettle();

      // Check real-time preview chips appeared
      expect(find.text('語意解析結果：'), findsOneWidget);
      expect(find.text('工作'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('彈性區塊 (Track 2)'), findsOneWidget);

      // Toggle track to Anchored
      await tester.tap(find.text('彈性區塊 (Track 2)'));
      await tester.pumpAndSettle();
      expect(find.text('固定錨定 (Track 1)'), findsOneWidget);

      // Submit event
      await tester.tap(find.text('新增日程'));
      await tester.pumpAndSettle();

      // Verify event was saved to SQLite database
      final events = await (testDb.select(testDb.calendarEvents)).get();
      expect(events.length, equals(1));
      expect(events.first.title, equals('開會'));
      expect(events.first.isAnchored, isTrue);
      expect(events.first.priority, equals(1));

      // Unmount and drain drift stream-cancel timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
