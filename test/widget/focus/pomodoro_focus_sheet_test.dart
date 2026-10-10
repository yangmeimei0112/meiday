import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/focus/presentation/widgets/pomodoro_focus_sheet.dart';
import 'package:smart_calendar_hub/features/focus/presentation/widgets/soundscape_drawer.dart';

void main() {
  group('PomodoroFocusSheet Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_sheet.db');
      testDb = AppDatabase(connection);
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('Renders timer, starts focus, and toggles controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PomodoroFocusSheet(
                eventId: 'task-1',
                eventTitle: '編寫端對端測試',
              ),
            ),
          ),
        ),
      );

      // Verify task title and initial ready state
      expect(find.text('編寫端對端測試'), findsOneWidget);
      expect(find.text('準備專注 (Ready)'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('開始專注 (25m)'), findsOneWidget);

      // Tap start focus button
      await tester.tap(find.text('開始專注 (25m)'));
      await tester.pumpAndSettle();

      // State should transition to focusing with pause/skip controls
      expect(find.text('專注中 (Focus)'), findsOneWidget);
      expect(find.text('暫停'), findsOneWidget);
      expect(find.text('跳過'), findsOneWidget);
      expect(find.text('結束'), findsOneWidget);

      // Tap soundscape icon to open soundscape drawer
      await tester.tap(find.byTooltip('環境音效'));
      await tester.pumpAndSettle();
      expect(find.byType(SoundscapeDrawer), findsOneWidget);
      expect(find.text('環境白噪音 (Soundscapes)'), findsOneWidget);
    });
  });
}
