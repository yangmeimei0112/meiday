import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../application/commands/cascade_schedule_command.dart';
import '../../application/commands/models/event_time_shift.dart';
import '../../application/commands/move_event_command.dart';
import '../../application/commands/resize_event_command.dart';
import '../../application/undo/undo_stack_providers.dart';
import '../../domain/entities/schedule_models.dart';
import '../../../social/application/commands/convert_keep_to_event_command.dart';
import '../../../social/domain/entities/calendar_space.dart';
import '../../../social/domain/entities/keep_item.dart';
import '../../../social/presentation/providers/heatmap_providers.dart';
import '../../../social/presentation/providers/space_providers.dart';
import '../../../social/presentation/sheets/event_detail_sheet.dart';
import '../../../social/presentation/widgets/availability_heatmap_overlay.dart';
import '../../../social/domain/entities/availability_slot.dart';
import '../providers/calendar_providers.dart';
import 'time_block_card.dart';

class TimeGridCanvas extends ConsumerStatefulWidget {
  final int columnCount; // 7 for week, 3 for threeDay, 1 for day

  const TimeGridCanvas({
    super.key,
    required this.columnCount,
  });

  @override
  ConsumerState<TimeGridCanvas> createState() => _TimeGridCanvasState();
}

class _TimeGridCanvasState extends ConsumerState<TimeGridCanvas> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final currentHour = DateTime.now().hour;
        final hourHeight = ref.read(hourHeightScaleProvider);
        final initialOffset = ((currentHour - 1).clamp(0, 23)) * hourHeight;
        _scrollController.jumpTo(initialOffset);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _computeVisibleDays(DateTime baseDate) {
    if (widget.columnCount == 1) {
      return [DateTime(baseDate.year, baseDate.month, baseDate.day)];
    } else if (widget.columnCount == 3) {
      return List.generate(3, (i) {
        final day = baseDate.add(Duration(days: i));
        return DateTime(day.year, day.month, day.day);
      });
    } else {
      // 7-day week (start from Monday)
      final weekday = baseDate.weekday; // 1 is Monday
      final monday = baseDate.subtract(Duration(days: weekday - 1));
      return List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        return DateTime(day.year, day.month, day.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final hourHeight = ref.watch(hourHeightScaleProvider);
    final activeSpaceIds = ref.watch(activeSpaceIdsProvider);
    final AsyncValue<List<CalendarEvent>> eventsAsync;
    if (activeSpaceIds.isNotEmpty) {
      eventsAsync = ref.watch(filteredCalendarEventsStreamProvider);
    } else {
      eventsAsync = ref.watch(calendarEventsStreamProvider);
    }
    final allEvents = eventsAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

    final visibleDays = _computeVisibleDays(selectedDate);

    return Column(
      children: [
        // Day Headers
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Left time gutter spacer
              const SizedBox(width: 56),
              const VerticalDivider(width: 1),
              // Day columns header
              for (int i = 0; i < visibleDays.length; i++)
                Expanded(
                  child: _DayHeaderWidget(
                    day: visibleDays[i],
                    isSelected: _isSameDay(visibleDays[i], selectedDate),
                    isToday: _isSameDay(visibleDays[i], now),
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = visibleDays[i];
                    },
                  ),
                ),
            ],
          ),
        ),

        // 24-Hour Time Grid Canvas (Zero-drift single scroll view)
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: 24 * hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time gutter
                  _TimeGutterWidget(
                    hourHeight: hourHeight,
                    isDark: isDark,
                  ),
                  const VerticalDivider(width: 1),
                  // Matrix of day columns
                  for (int i = 0; i < visibleDays.length; i++)
                    Expanded(
                      child: _DayColumnWidget(
                        day: visibleDays[i],
                        hourHeight: hourHeight,
                        isToday: _isSameDay(visibleDays[i], now),
                        currentTime: now,
                        dayEvents: _filterEventsForDay(allEvents, visibleDays[i]),
                        allEvents: allEvents,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static List<CalendarEvent> _filterEventsForDay(List<CalendarEvent> events, DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    return events.where((e) {
      if (e.isDeleted || e.startTime == null || e.endTime == null) return false;
      return e.startTime!.isBefore(endOfDay) && e.endTime!.isAfter(startOfDay);
    }).toList();
  }
}

class _DayHeaderWidget extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _DayHeaderWidget({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekdayLabel = '週${_weekdays[day.weekday - 1]}';

    return InkWell(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayLabel,
              style: TextStyle(
                fontSize: 11,
                color: isToday
                    ? AppColors.primary
                    : (isDark ? Colors.white60 : Colors.black54),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary
                    : (isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isToday
                      ? Colors.white
                      : (isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white : const Color(0xFF0F172A))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeGutterWidget extends StatelessWidget {
  final double hourHeight;
  final bool isDark;

  const _TimeGutterWidget({
    required this.hourHeight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          for (int hour = 0; hour < 24; hour++)
            Positioned(
              top: hour * hourHeight - 8,
              left: 0,
              right: 8,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumnWidget extends ConsumerWidget {
  final DateTime day;
  final double hourHeight;
  final bool isToday;
  final DateTime currentTime;
  final List<CalendarEvent> dayEvents;
  final List<CalendarEvent> allEvents;

  const _DayColumnWidget({
    required this.day,
    required this.hourHeight,
    required this.isToday,
    required this.currentTime,
    required this.dayEvents,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isHeatmapActive = ref.watch(isHeatmapActiveProvider);
    final daySlots = isHeatmapActive ? ref.watch(dayAvailabilitySlotsProvider(day)) : const <AvailabilitySlot>[];

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) =>
          details.data is CalendarEvent || details.data is KeepItem,
      onAcceptWithDetails: (details) async {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final localY = renderBox.globalToLocal(details.offset).dy;
        final snappedMinutes = TimeBlockSnapHelper.snapMinutesFromOffset(localY, hourHeight);

        final newStartTime = DateTime(
          day.year,
          day.month,
          day.day,
          snappedMinutes ~/ 60,
          snappedMinutes % 60,
        );

        if (details.data is CalendarEvent) {
          final draggedEvent = details.data as CalendarEvent;
          final scheduler = ref.read(autoCascadeSchedulerProvider);
          final scheduleResult = scheduler.schedule(
            existingEvents: allEvents,
            movingEvent: draggedEvent,
            targetStartTime: newStartTime,
          );

          if (scheduleResult.hasConflicts) {
            ref.read(activeConflictProvider.notifier).state = scheduleResult.conflicts.first;
          } else {
            ref.read(activeConflictProvider.notifier).state = null;
            final db = ref.read(appDatabaseProvider);
            final undoManager = ref.read(undoStackManagerProvider);

            if (scheduleResult.modifiedEvents.length == 1) {
              final moved = scheduleResult.modifiedEvents.first;
              final cmd = MoveEventCommand(
                id: UuidUtils.generate(),
                description: '移動「${moved.title}」至 ${_formatTime(moved.startTime)}',
                timestamp: DateTime.now(),
                eventId: moved.id,
                previousStartTime: draggedEvent.startTime,
                previousEndTime: draggedEvent.endTime,
                targetStartTime: moved.startTime,
                targetEndTime: moved.endTime,
                database: db,
                userId: moved.userId,
              );
              await undoManager.execute(cmd);
            } else {
              final shifts = <EventTimeShift>[];
              for (final modified in scheduleResult.modifiedEvents) {
                final original = allEvents.firstWhere(
                  (e) => e.id == modified.id,
                  orElse: () => draggedEvent,
                );
                shifts.add(EventTimeShift(
                  eventId: modified.id,
                  title: modified.title,
                  previousStartTime: original.startTime,
                  previousEndTime: original.endTime,
                  targetStartTime: modified.startTime,
                  targetEndTime: modified.endTime,
                ));
              }
              final cascadeCmd = CascadeScheduleCommand(
                id: UuidUtils.generate(),
                description: '自動順延排程 (${scheduleResult.modifiedEvents.length} 項行程)',
                timestamp: DateTime.now(),
                shifts: shifts,
                database: db,
                userId: draggedEvent.userId,
              );
              await undoManager.execute(cascadeCmd);
            }
          }
        } else if (details.data is KeepItem) {
          final keepItem = details.data as KeepItem;
          final db = ref.read(appDatabaseProvider);
          final undoManager = ref.read(undoStackManagerProvider);
          final defaultSpace = await db.spaceDao.getDefaultSpace();
          final spaceId = defaultSpace?.id ?? 'default_space';
          final targetEndTime = newStartTime.add(const Duration(minutes: 30));

          final cmd = ConvertKeepToEventCommand(
            id: UuidUtils.generate(),
            description: '將「${keepItem.title}」排程至 ${_formatTime(newStartTime)}',
            timestamp: DateTime.now(),
            keepItem: keepItem,
            targetStartTime: newStartTime,
            targetEndTime: targetEndTime,
            targetSpaceId: spaceId,
            database: db,
            userId: keepItem.userId,
          );
          await undoManager.execute(cmd);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Heatmap overlay if active
              if (isHeatmapActive)
                AvailabilityHeatmapOverlay(
                  slots: daySlots,
                  hourHeight: hourHeight,
                ),

              // Hour divider grid lines
              for (int hour = 0; hour < 24; hour++)
                Positioned(
                  top: hour * hourHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                  ),
                ),

              // Events in this column
              for (final event in dayEvents)
                _buildPositionedEventCard(context, ref, event),

              // Red hairline current-time indicator
              if (isToday)
                _buildCurrentTimeHairline(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionedEventCard(BuildContext context, WidgetRef ref, CalendarEvent event) {
    final startMinutes = (event.startTime!.hour * 60) + event.startTime!.minute;
    final topOffset = (startMinutes / 60.0) * hourHeight;
    final linkedSpacesMap = ref.watch(eventLinkedSpacesMapProvider).value ?? const {};
    final spaces = linkedSpacesMap[event.id] ?? const <CalendarSpace>[];

    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      child: TimeBlockCard(
        event: event,
        hourHeight: hourHeight,
        linkedSpaces: spaces,
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EventDetailSheet(eventId: event.id, userId: event.userId),
          );
        },
        onResized: (newDuration) async {
          final scheduler = ref.read(autoCascadeSchedulerProvider);
          final result = scheduler.resize(
            existingEvents: allEvents,
            resizingEvent: event,
            newDurationMinutes: newDuration,
          );

          if (result.hasConflicts) {
            ref.read(activeConflictProvider.notifier).state = result.conflicts.first;
          } else {
            ref.read(activeConflictProvider.notifier).state = null;
            final db = ref.read(appDatabaseProvider);
            final undoManager = ref.read(undoStackManagerProvider);

            if (result.modifiedEvents.length == 1) {
              final resized = result.modifiedEvents.first;
              final cmd = ResizeEventCommand(
                id: UuidUtils.generate(),
                description: '調整「${resized.title}」工時至 ${resized.estimatedMinutes} 分鐘',
                timestamp: DateTime.now(),
                eventId: resized.id,
                previousStartTime: event.startTime,
                previousEndTime: event.endTime,
                previousEstimatedMinutes: event.estimatedMinutes,
                targetStartTime: resized.startTime,
                targetEndTime: resized.endTime,
                targetEstimatedMinutes: resized.estimatedMinutes,
                database: db,
                userId: resized.userId,
              );
              await undoManager.execute(cmd);
            } else {
              final shifts = <EventTimeShift>[];
              for (final modified in result.modifiedEvents) {
                final original = allEvents.firstWhere((e) => e.id == modified.id, orElse: () => event);
                shifts.add(EventTimeShift(
                  eventId: modified.id,
                  title: modified.title,
                  previousStartTime: original.startTime,
                  previousEndTime: original.endTime,
                  targetStartTime: modified.startTime,
                  targetEndTime: modified.endTime,
                ));
              }
              final cascadeCmd = CascadeScheduleCommand(
                id: UuidUtils.generate(),
                description: '調整工時自動順延 (${result.modifiedEvents.length} 項行程)',
                timestamp: DateTime.now(),
                shifts: shifts,
                database: db,
                userId: event.userId,
              );
              await undoManager.execute(cascadeCmd);
            }
          }
        },
      ),
    );
  }

  Widget _buildCurrentTimeHairline() {
    final currentMinutes = (currentTime.hour * 60) + currentTime.minute + (currentTime.second / 60.0);
    final topOffset = (currentMinutes / 60.0) * hourHeight;

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.capacityOverloaded,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.capacityOverloaded,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
