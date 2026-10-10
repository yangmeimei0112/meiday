import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/ocr_service.dart';
import 'package:smart_calendar_hub/features/capture/domain/entities/ocr_capture_draft.dart';
import 'package:smart_calendar_hub/features/capture/presentation/widgets/ocr_capture_dialog.dart';

void main() {
  group('OcrCaptureDialog Widget Tests', () {
    late InMemoryDatabaseConnectionFactory dbFactory;
    late AppDatabase testDb;

    setUp(() {
      dbFactory = InMemoryDatabaseConnectionFactory();
      final connection = dbFactory.createConnection('test_ocr_dialog.db');
      testDb = AppDatabase(connection);
    });

    tearDown(() async {
      await testDb.close();
    });

    testWidgets('Renders confidence badge, engine source, and creates event on confirm', (tester) async {
      final draft = OcrCaptureDraft(
        rawText: '2026/10/20 14:00 專案架構評審\n地點：會議室 C',
        cleanTitle: '專案架構評審',
        location: '會議室 C',
        startTime: DateTime(2026, 10, 20, 14, 0),
        endTime: DateTime(2026, 10, 20, 15, 0),
        confidence: 0.95,
        engineSource: OcrEngineSource.winrt,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OcrCaptureDialog(draft: draft),
            ),
          ),
        ),
      );

      // Verify header and badges
      expect(find.text('OCR 行程智慧識別'), findsOneWidget);
      expect(find.text('高可信度 95%'), findsOneWidget);
      expect(find.text('識別引擎：Windows WinRT (離線 0 成本)'), findsOneWidget);
      expect(find.text('專案架構評審'), findsOneWidget);
      expect(find.text('會議室 C'), findsOneWidget);

      // Confirm event creation
      await tester.tap(find.text('確認建立日程'));
      await tester.pumpAndSettle();

      // Verify event written to database
      final events = await testDb.select(testDb.calendarEvents).get();
      expect(events.length, equals(1));
      expect(events.first.title, equals('專案架構評審'));
      expect(events.first.location, equals('會議室 C'));
      expect(events.first.description, contains('由 OCR 辨識匯入'));
    });
  });
}
