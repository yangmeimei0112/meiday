import '../../../../core/database/app_database.dart';
import '../../../../core/platform/widget_service.dart';
import '../domain/entities/today_widget_snapshot.dart';

class WidgetSnapshotExporter {
  final AppDatabase _db;
  final WidgetSyncService _widgetService;

  WidgetSnapshotExporter({
    required AppDatabase db,
    required WidgetSyncService widgetService,
  })  : _db = db,
        _widgetService = widgetService;

  /// Builds snapshot for given date and exports to platform widget storage
  Future<TodayWidgetSnapshot> exportSnapshot({DateTime? targetDate}) async {
    final now = targetDate ?? DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    // 1. Fetch today's scheduled calendar events
    final allEvents = await _db.eventDao.watchAllEvents().first;
    final todayEvents = allEvents.where((e) {
      if (e.isDeleted) return false;
      if (e.startTime == null) return false;
      return e.startTime!.isBefore(endOfDay) &&
          (e.endTime?.isAfter(startOfDay) ?? true);
    }).toList();

    // 2. Fetch pending tasks (sorted by priority descending)
    final pendingTasks = allEvents.where((e) {
      if (e.isDeleted) return false;
      return e.status == 'pending' || e.status == 'in_progress';
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final topTasks = pendingTasks.take(5).map((t) => TodayWidgetTaskItem(
          id: t.id,
          title: t.title,
          isCompleted: t.status == 'completed',
          priority: t.priority,
        )).toList();

    final eventItems = todayEvents.map((e) => TodayWidgetEventItem(
          id: e.id,
          title: e.title,
          startTime: e.startTime!.toIso8601String(),
          endTime: (e.endTime ?? e.startTime!.add(const Duration(minutes: 30)))
              .toIso8601String(),
          isAllDay: e.isAllDay,
          isAnchored: e.isAnchored,
          color: e.color,
        )).toList();

    // 3. Compute capacity metrics
    int totalEstimatedMinutes = 0;
    int totalActualMinutes = 0;
    for (final e in todayEvents) {
      totalEstimatedMinutes += e.estimatedMinutes;
      totalActualMinutes += e.actualMinutes;
    }

    final capacityHours = (totalEstimatedMinutes / 60.0);

    final snapshot = TodayWidgetSnapshot(
      dateIso: '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      events: eventItems,
      topTasks: topTasks,
      capacityHours: double.parse(capacityHours.toStringAsFixed(1)),
      totalFocusMinutes: totalActualMinutes,
      generatedAt: DateTime.now(),
    );

    // Invariant check: Snapshot must strictly stay well under 5MB limit
    if (!snapshot.isWithinSizeLimit) {
      throw Exception('Snapshot size exceeds 5MB limit: ${snapshot.byteSize} bytes');
    }

    // 4. Export to native widget service
    await _widgetService.updateTodaySnapshot(snapshot.toJson());
    await _widgetService.refreshWidgets();

    return snapshot;
  }
}
