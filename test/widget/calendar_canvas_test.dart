import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/features/calendar/domain/entities/schedule_models.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/widgets/capacity_bar.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/widgets/conflict_proposal_banner.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/widgets/month_view_grid.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/widgets/time_block_card.dart';
import 'package:smart_calendar_hub/features/calendar/presentation/widgets/time_grid_canvas.dart';

void main() {
  group('Calendar Canvas Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_canvas.db');
      testDb = AppDatabase(connection);
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('CalendarScreen renders header, capacity bar, and Week canvas by default', (tester) async {
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
            calendarEventsStreamProvider.overrideWith((ref) => Stream.value(<CalendarEvent>[])),
            currentTimeProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 10, 10, 0))),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header elements
      expect(find.text('今日'), findsOneWidget);
      expect(find.byType(CapacityBar), findsOneWidget);

      // Default view is Week view
      expect(find.byType(TimeGridCanvas), findsOneWidget);
      expect(find.text('週一'), findsOneWidget);
      expect(find.text('週日'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('Switching between Month, Week, 3-Day, and Day views updates active canvas', (tester) async {
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
            calendarEventsStreamProvider.overrideWith((ref) => Stream.value(<CalendarEvent>[])),
            currentTimeProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 10, 10, 0))),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Month view
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(find.byType(MonthViewGrid), findsOneWidget);

      // Switch to 3-Day view
      await tester.tap(find.text('3日'));
      await tester.pumpAndSettle();
      expect(find.byType(TimeGridCanvas), findsOneWidget);

      // Switch to Day view
      await tester.tap(find.text('日'));
      await tester.pumpAndSettle();
      expect(find.byType(TimeGridCanvas), findsOneWidget);

      // Switch back to Week view
      await tester.tap(find.text('週'));
      await tester.pumpAndSettle();
      expect(find.byType(TimeGridCanvas), findsOneWidget);
    });

    testWidgets('TimeBlockCard visually distinguishes Track 1 Anchor vs Track 2 Flexible tasks', (tester) async {
      final now = DateTime.now();
      final anchorEvent = CalendarEvent(
        id: 'anchor_1',
        userId: 'u1',
        title: 'Executive Sync',
        startTime: DateTime(now.year, now.month, now.day, 10, 0),
        endTime: DateTime(now.year, now.month, now.day, 11, 0),
        isAnchored: true, // Track 1
        createdAt: now,
        updatedAt: now,
      );

      final flexibleEvent = CalendarEvent(
        id: 'flex_1',
        userId: 'u1',
        title: 'Write Unit Tests',
        startTime: DateTime(now.year, now.month, now.day, 14, 0),
        endTime: DateTime(now.year, now.month, now.day, 15, 30),
        isAnchored: false, // Track 2
        estimatedMinutes: 90,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TimeBlockCard(event: anchorEvent),
                TimeBlockCard(event: flexibleEvent),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Executive Sync'), findsOneWidget);
      expect(find.text('Write Unit Tests'), findsOneWidget);

      // Anchor card has lock icon
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Flexible card has checkbox icon
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('ConflictProposalBanner displays non-blocking proposals when conflict is active', (tester) async {
      final now = DateTime.now();

      final blocked = CalendarEvent(
        id: 'b1',
        userId: 'u1',
        title: 'Write Documentation',
        startTime: DateTime(now.year, now.month, now.day, 10, 0),
        endTime: DateTime(now.year, now.month, now.day, 11, 0),
        createdAt: now,
        updatedAt: now,
      );

      final anchor = CalendarEvent(
        id: 'a1',
        userId: 'u1',
        title: 'Client Review Meeting',
        startTime: DateTime(now.year, now.month, now.day, 10, 30),
        endTime: DateTime(now.year, now.month, now.day, 11, 30),
        isAnchored: true,
        createdAt: now,
        updatedAt: now,
      );

      final conflict = ScheduleConflict.boundaryHalt(
        blockedEvent: blocked,
        proposedStartTime: blocked.startTime!,
        collidingAnchor: anchor,
        overlapMinutes: 30,
        proposals: [
          ProposalAlternative.shiftPastAnchor(
            label: '順延至會議後 (11:30)',
            description: '推遲至會議結束後',
            newStartTime: DateTime(now.year, now.month, now.day, 11, 30),
            newEndTime: DateTime(now.year, now.month, now.day, 12, 30),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            calendarEventsStreamProvider.overrideWith((ref) => Stream.value(<CalendarEvent>[])),
            currentTimeProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 10, 10, 0))),
            activeConflictProvider.overrideWith((ref) => conflict),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should be visible
      expect(find.byType(ConflictProposalBanner), findsOneWidget);
      expect(find.textContaining('發生排程衝突'), findsOneWidget);
      expect(find.text('順延至會議後 (11:30)'), findsOneWidget);
      expect(find.text('忽略/重疊'), findsOneWidget);

      // Tapping ignore dismisses banner
      await tester.tap(find.text('忽略/重疊'));
      await tester.pumpAndSettle();
    });

    testWidgets('Command Palette button launches modal overlay', (tester) async {
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
            calendarEventsStreamProvider.overrideWith((ref) => Stream.value(<CalendarEvent>[])),
            currentTimeProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 10, 10, 0))),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap command palette icon button
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('輸入指令、搜尋視圖或操作快捷鍵...'), findsOneWidget);
      expect(find.text('切換至月視圖 (Month View)'), findsOneWidget);
      expect(find.text('切換至週視圖 (Week View)'), findsOneWidget);
    });
  });
}
