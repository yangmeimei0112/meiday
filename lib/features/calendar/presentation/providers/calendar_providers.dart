import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/schedule_models.dart';
import '../../domain/services/auto_cascade_scheduler.dart';
import '../../domain/services/capacity_calculator.dart';

/// Currently selected date in the calendar canvas.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Current calendar canvas view mode (month, week, threeDay, day).
final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) {
  return CalendarViewMode.week;
});

/// Hour height scaling factor for zooming the canvas (between 30.0 and 120.0).
final hourHeightScaleProvider = StateProvider<double>((ref) => 60.0);

/// Auto-cascade scheduling service instance.
final autoCascadeSchedulerProvider = Provider<AutoCascadeScheduler>((ref) {
  return AutoCascadeSchedulerImpl();
});

/// Workload capacity calculator instance.
final capacityCalculatorProvider = Provider<CapacityCalculator>((ref) {
  return CapacityCalculatorImpl();
});

/// Real-time stream of all non-deleted calendar events from the active database.
final calendarEventsStreamProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.eventDao.watchAllEvents().map((list) => list.map(CalendarEvent.fromData).toList());
});

/// Active scheduling conflict currently awaiting user resolution.
final activeConflictProvider = StateProvider<ScheduleConflict?>((ref) => null);

/// Daily capacity calculations for the currently selected date.
final dailyCapacityProvider = Provider<WorkloadCapacity>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final eventsAsync = ref.watch(calendarEventsStreamProvider);
  final events = eventsAsync.value ?? [];
  final calculator = ref.watch(capacityCalculatorProvider);
  return calculator.calculate(date: selectedDate, events: events);
});

/// Live clock ticker emitting current DateTime every 30 seconds for red hairline indicator.
final currentTimeProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (!controller.isClosed) {
      controller.add(DateTime.now());
    }
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
