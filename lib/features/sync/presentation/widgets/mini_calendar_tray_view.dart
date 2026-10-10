import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../calendar/domain/entities/schedule_models.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../capture/presentation/widgets/quick_capture_modal.dart';
import '../providers/sync_providers.dart';

class MiniCalendarTrayView extends ConsumerStatefulWidget {
  final VoidCallback? onExpandToMainApp;

  const MiniCalendarTrayView({super.key, this.onExpandToMainApp});

  @override
  ConsumerState<MiniCalendarTrayView> createState() =>
      _MiniCalendarTrayViewState();
}

class _MiniCalendarTrayViewState extends ConsumerState<MiniCalendarTrayView> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: Container(
        width: 360,
        height: 480,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Date & Quick Actions
            _buildHeader(context),
            const SizedBox(height: 12),

            // Mini Week Strip
            _buildWeekStrip(context),
            const SizedBox(height: 12),

            const Divider(height: 1),
            const SizedBox(height: 8),

            // Events & Tasks list
            Expanded(
              child: eventsAsync.when(
                data: (events) => _buildEventsList(context, events),
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Text('載入失敗：$e', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Footer action buttons
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedDate.month}月${_selectedDate.day}日',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isToday ? '今日焦點' : '檢視行程',
              style: TextStyle(
                fontSize: 12,
                color: isToday ? AppColors.primary : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.flash_on, size: 20, color: AppColors.primary),
              tooltip: '快速速記 (Win+Shift+C)',
              onPressed: () {
                QuickCaptureModal.show(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '隱藏托盤',
              onPressed: () {
                ref.read(trayServiceProvider).hideMiniCalendar();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekStrip(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final isSelected = day.year == _selectedDate.year &&
            day.month == _selectedDate.month &&
            day.day == _selectedDate.day;
        final isToday = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;

        const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedDate = day),
          child: Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  weekdayLabels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? AppColors.primary
                            : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEventsList(BuildContext context, List<CalendarEvent> allEvents) {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final dayEvents = allEvents.where((e) {
      if (e.isDeleted) return false;
      if (e.startTime == null) return false;
      return e.startTime!.isBefore(endOfDay) &&
          (e.endTime?.isAfter(startOfDay) ?? true);
    }).toList()
      ..sort((a, b) => (a.startTime ?? DateTime.now())
          .compareTo(b.startTime ?? DateTime.now()));

    if (dayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 36, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text(
              '今日尚無安排行程',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: dayEvents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final event = dayEvents[index];
        final timeStr = event.isAllDay
            ? '全天'
            : '${event.startTime?.hour.toString().padLeft(2, '0')}:${event.startTime?.minute.toString().padLeft(2, '0')}';

        final isCompleted = event.status == 'completed';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.grey.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCompleted
                  ? Colors.grey.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isCompleted,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (val) async {
                  final db = ref.read(appDatabaseProvider);
                  await (db.update(db.calendarEvents)
                        ..where((t) => t.id.equals(event.id)))
                      .write(
                    CalendarEventsCompanion(
                      status: Value(val == true ? 'completed' : 'pending'),
                      updatedAt: Value(DateTime.now()),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted ? Colors.grey : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (event.isAnchored)
                const Tooltip(
                  message: '錨定會議 (Track 1)',
                  child: Icon(Icons.anchor, size: 14, color: AppColors.warning),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('同步狀態', style: TextStyle(fontSize: 12)),
          onPressed: () {
            ref.read(syncCoordinatorProvider.notifier).triggerManualSync('guest');
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.open_in_full, size: 14),
          label: const Text('展開完整視窗', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () {
            ref.read(trayServiceProvider).hideMiniCalendar();
            widget.onExpandToMainApp?.call();
          },
        ),
      ],
    );
  }
}
