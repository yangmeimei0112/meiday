import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/tray_service.dart';
import 'package:smart_calendar_hub/features/sync/presentation/widgets/mini_calendar_tray_view.dart';

void main() {
  group('MiniCalendarTrayView Widget Tests (Feature #44)', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;
    late MockTrayService mockTrayService;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      testDb = AppDatabase(dbFactory.createConnection('test_mini_tray.db'));
      mockTrayService = MockTrayService();
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('Renders mini calendar header, weekday strip, and empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            trayServiceProvider.overrideWithValue(mockTrayService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: MiniCalendarTrayView()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('今日焦點'), findsOneWidget);
      expect(find.text('今日尚無安排行程'), findsOneWidget);
      expect(find.text('展開完整視窗'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('Renders today event item and toggles task completion checkbox', (tester) async {
      final now = DateTime.now();
      await testDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'tray-evt-1',
          userId: 'guest',
          title: 'Review PR & Deploy',
          startTime: Value(DateTime(now.year, now.month, now.day, 14, 0)),
          endTime: Value(DateTime(now.year, now.month, now.day, 15, 0)),
          isAnchored: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            trayServiceProvider.overrideWithValue(mockTrayService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: MiniCalendarTrayView()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Review PR & Deploy'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Checkbox tap toggles completion in SQLite
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final updated = await (testDb.select(testDb.calendarEvents)
            ..where((t) => t.id.equals('tray-evt-1')))
          .getSingle();
      expect(updated.status, equals('completed'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('Tapping expand button triggers callback and hides mini window', (tester) async {
      bool expandTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            trayServiceProvider.overrideWithValue(mockTrayService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: MiniCalendarTrayView(
                  onExpandToMainApp: () {
                    expandTriggered = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('展開完整視窗'));
      await tester.pumpAndSettle();

      expect(expandTriggered, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
