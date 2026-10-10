import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/widget_service.dart';
import 'package:smart_calendar_hub/features/sync/application/widget_snapshot_exporter.dart';

void main() {
  group('WidgetSnapshotExporter Unit Tests (Feature #46)', () {
    late InMemoryDatabaseConnectionFactory factory;
    late AppDatabase db;
    late MockWidgetSyncService mockWidgetService;
    late WidgetSnapshotExporter exporter;

    final targetDay = DateTime(2026, 10, 10, 14, 0);

    setUp(() {
      factory = InMemoryDatabaseConnectionFactory();
      db = AppDatabase(factory.createConnection('test_widget_export.db'));
      mockWidgetService = MockWidgetSyncService();
      exporter = WidgetSnapshotExporter(
        db: db,
        widgetService: mockWidgetService,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('exportSnapshot extracts today events and pending tasks accurately', () async {
      // Seed today's event
      await db.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'evt-w1',
          userId: 'user-1',
          title: 'Quarterly Planning',
          startTime: Value(DateTime(2026, 10, 10, 10, 0)),
          endTime: Value(DateTime(2026, 10, 10, 11, 30)),
          estimatedMinutes: const Value(90),
          actualMinutes: const Value(45),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Seed another event tomorrow (should be excluded)
      await db.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'evt-w2',
          userId: 'user-1',
          title: 'Tomorrow Meeting',
          startTime: Value(DateTime(2026, 10, 11, 10, 0)),
          endTime: Value(DateTime(2026, 10, 11, 11, 0)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final snapshot = await exporter.exportSnapshot(targetDate: targetDay);

      expect(snapshot.events.length, equals(1));
      expect(snapshot.events.first.title, equals('Quarterly Planning'));
      expect(snapshot.capacityHours, equals(1.5));
      expect(snapshot.totalFocusMinutes, equals(45));
      expect(snapshot.isWithinSizeLimit, isTrue);

      // Verify widget service received snapshot and refresh was called
      expect(mockWidgetService.refreshCallCount, equals(1));
      final cached = await mockWidgetService.getCachedSnapshot();
      expect(cached != null, isTrue);
      expect(cached?['date'], equals('2026-10-10'));
    });

    test('Snapshot strictly stays under 5MB size limit', () async {
      final snapshot = await exporter.exportSnapshot(targetDate: targetDay);
      expect(snapshot.byteSize, lessThan(5 * 1024 * 1024));
      // Under 10KB for reasonable daily events
      expect(snapshot.byteSize, lessThan(10 * 1024));
    });
  });
}
