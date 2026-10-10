import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/schedule_models.dart';
import '../providers/calendar_providers.dart';

class MonthViewGrid extends ConsumerWidget {
  const MonthViewGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(calendarEventsStreamProvider);
    final allEvents = eventsAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);

    // Compute calendar grid start (Monday before or on first day)
    final startWeekday = firstDayOfMonth.weekday; // 1 is Monday
    final calendarStartDate = firstDayOfMonth.subtract(Duration(days: startWeekday - 1));

    // Number of days to show (multiples of 7: typically 35 or 42)
    final totalDays = (lastDayOfMonth.difference(calendarStartDate).inDays + 7) ~/ 7 * 7;
    final gridDays = List.generate(totalDays, (i) => calendarStartDate.add(Duration(days: i)));

    final now = DateTime.now();

    return Column(
      children: [
        // Weekday header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: const Row(
            children: [
              _WeekdayHeaderCell('週一'),
              _WeekdayHeaderCell('週二'),
              _WeekdayHeaderCell('週三'),
              _WeekdayHeaderCell('週四'),
              _WeekdayHeaderCell('週五'),
              _WeekdayHeaderCell('週六'),
              _WeekdayHeaderCell('週日'),
            ],
          ),
        ),

        // Month Grid cells
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: gridDays.length,
            itemBuilder: (context, index) {
              final day = gridDays[index];
              final isCurrentMonth = day.month == selectedDate.month;
              final isToday = _isSameDay(day, now);
              final isSelected = _isSameDay(day, selectedDate);
              final dayEvents = _filterEventsForDay(allEvents, day);

              return _MonthDayCell(
                day: day,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                isSelected: isSelected,
                events: dayEvents,
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = day;
                },
                onDoubleTap: () {
                  ref.read(selectedDateProvider.notifier).state = day;
                  ref.read(calendarViewModeProvider.notifier).state = CalendarViewMode.day;
                },
              );
            },
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

class _WeekdayHeaderCell extends StatelessWidget {
  final String label;

  const _WeekdayHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> events;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _MonthDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number badge
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday
                        ? Colors.white
                        : (isCurrentMonth
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : (isDark ? Colors.white30 : Colors.black26)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Events preview chips
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const maxChips = 3;
                  final hasOverflow = events.length > maxChips;
                  final visibleCount = hasOverflow ? 2 : events.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < visibleCount; i++)
                        _EventMiniChip(event: events[i]),
                      if (hasOverflow)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            '+${events.length - 2} 更多',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMiniChip extends StatelessWidget {
  final CalendarEvent event;

  const _EventMiniChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: event.isAnchored
            ? (event.color != null ? Color(event.color!) : AppColors.anchorEvent)
            : (isDark ? AppColors.flexibleTaskFillDark : AppColors.flexibleTaskFillLight),
        borderRadius: BorderRadius.circular(3),
        border: event.isAnchored
            ? null
            : Border.all(color: AppColors.flexibleTask, width: 0.8),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: event.isAnchored
              ? Colors.white
              : (isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ),
    );
  }
}
