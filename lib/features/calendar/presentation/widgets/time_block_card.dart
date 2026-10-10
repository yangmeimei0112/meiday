import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../social/domain/entities/calendar_space.dart';
import '../../domain/entities/schedule_models.dart';

class TimeBlockSnapHelper {
  static const int snapIntervalMinutes = 15;

  static int snapMinutesFromOffset(double offsetY, double hourHeight) {
    final double rawMinutes = (offsetY / hourHeight) * 60.0;
    final int snappedMinutes = (rawMinutes / snapIntervalMinutes).round() * snapIntervalMinutes;
    return snappedMinutes.clamp(0, 24 * 60 - snapIntervalMinutes);
  }

  static double offsetFromMinutes(int minutes, double hourHeight) {
    return (minutes / 60.0) * hourHeight;
  }
}

class TimeBlockCard extends StatelessWidget {
  final CalendarEvent event;
  final double hourHeight;
  final List<CalendarSpace> linkedSpaces;
  final void Function(DateTime newStart, DateTime newEnd)? onRescheduled;
  final void Function(int newDurationMinutes)? onResized;
  final VoidCallback? onTap;

  const TimeBlockCard({
    super.key,
    required this.event,
    this.hourHeight = 60.0,
    this.linkedSpaces = const [],
    this.onRescheduled,
    this.onResized,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationMinutes = event.durationMinutes;
    final height = (durationMinutes / 60.0) * hourHeight;
    final clampedHeight = height < 22.0 ? 22.0 : height;

    final cardWidget = Container(
      height: clampedHeight,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: event.isAnchored
            ? (event.color != null ? Color(event.color!) : AppColors.anchorEvent)
            : (isDark ? AppColors.flexibleTaskFillDark : AppColors.flexibleTaskFillLight),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: event.isAnchored
              ? AppColors.anchorEventBorder
              : AppColors.flexibleTask,
          width: event.isAnchored ? 1.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Multi-space left vertical indicator strip
          if (linkedSpaces.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                child: SizedBox(
                  width: 4,
                  child: linkedSpaces.length == 1
                      ? ColoredBox(color: linkedSpaces.first.colorValue)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: linkedSpaces
                              .map((s) => Expanded(
                                    child: ColoredBox(color: s.colorValue),
                                  ))
                              .toList(),
                        ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(linkedSpaces.isNotEmpty ? 8 : 6, 4, 6, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.isAnchored)
                  const Padding(
                    padding: EdgeInsets.only(right: 4, top: 2),
                    child: Icon(Icons.lock, size: 12, color: Colors.white),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    child: Icon(
                      event.status == 'completed'
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 13,
                      color: AppColors.flexibleTask,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: clampedHeight > 45 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: event.isAnchored
                                    ? Colors.white
                                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                          ),
                          if (linkedSpaces.length > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              linkedSpaces.map((s) => s.icon ?? '').where((ic) => ic.isNotEmpty).join(' '),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                      if (clampedHeight >= 36) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)} (${durationMinutes}m)',
                          style: TextStyle(
                            fontSize: 10,
                            color: event.isAnchored
                                ? Colors.white70
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom resize handle (only for flexible or resizable events when height permits)
          if (clampedHeight >= 30)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  if (onResized == null) return;
                  final deltaMinutes = (details.delta.dy / hourHeight * 60).round();
                  if (deltaMinutes != 0) {
                    final newMins = (durationMinutes + deltaMinutes).clamp(15, 24 * 60);
                    onResized!(newMins);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: Container(
                    height: 8,
                    alignment: Alignment.center,
                    child: Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: event.isAnchored
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.flexibleTask.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: LongPressDraggable<CalendarEvent>(
        data: event,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(6),
          color: Colors.transparent,
          child: SizedBox(
            width: 140,
            child: Opacity(
              opacity: 0.9,
              child: cardWidget,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: cardWidget,
        ),
        child: cardWidget,
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
