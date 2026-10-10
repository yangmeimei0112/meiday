import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/social/domain/entities/optimal_meeting_slot.dart';
import 'package:smart_calendar_hub/features/social/presentation/sheets/optimal_meeting_sheet.dart';

void main() {
  group('OptimalMeetingSheet Widget Tests', () {
    testWidgets('OptimalMeetingSheet renders duration chips and recommends available slots', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OptimalMeetingSlot? selectedSlot;
      final targetDate = DateTime(2026, 10, 10);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OptimalMeetingSheet(
                targetDate: targetDate,
                onSelectSlot: (slot) {
                  selectedSlot = slot;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and title
      expect(find.text('最佳空檔探測器 (Optimal Meeting)'), findsOneWidget);
      expect(find.text('會議時長：'), findsOneWidget);

      // Verify duration chips
      expect(find.text('15 分鐘'), findsOneWidget);
      expect(find.text('30 分鐘'), findsOneWidget);
      expect(find.text('45 分鐘'), findsOneWidget);
      expect(find.text('60 分鐘'), findsOneWidget);
      expect(find.text('90 分鐘'), findsOneWidget);

      // Verify candidate cards and recommendation badges
      expect(find.text('🟢 推薦'), findsWidgets);
      expect(find.text('選用時段'), findsWidgets);

      // Tap on the first '選用時段' button
      await tester.tap(find.text('選用時段').first);
      await tester.pumpAndSettle();

      expect(selectedSlot, isNotNull);
      expect(selectedSlot!.durationMinutes, equals(30));
      expect(selectedSlot!.isZeroConflict, isTrue);
    });

    testWidgets('Switching duration chips dynamically recalculates slot durations', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      OptimalMeetingSlot? selectedSlot;
      final targetDate = DateTime(2026, 10, 10);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OptimalMeetingSheet(
                targetDate: targetDate,
                onSelectSlot: (slot) {
                  selectedSlot = slot;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to 60 minutes
      await tester.tap(find.text('60 分鐘'));
      await tester.pumpAndSettle();

      // Tap '選用時段'
      await tester.tap(find.text('選用時段').first);
      await tester.pumpAndSettle();

      expect(selectedSlot, isNotNull);
      expect(selectedSlot!.durationMinutes, equals(60));
    });
  });
}
