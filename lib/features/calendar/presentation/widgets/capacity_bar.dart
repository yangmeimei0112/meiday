import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/schedule_models.dart';
import '../providers/calendar_providers.dart';
import '../../../focus/presentation/providers/focus_providers.dart';

class CapacityBar extends ConsumerWidget {
  const CapacityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(dailyCapacityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pomodoroState = ref.watch(pomodoroControllerProvider);
    final todayFocusMinutes = ref.watch(todayFocusMinutesStreamProvider).value ?? 0;
    final todayPomodoroCount = ref.watch(todayPomodoroCountStreamProvider).value ?? 0;

    final displayCount = todayPomodoroCount > 0 ? todayPomodoroCount : pomodoroState.completedCyclesCount;
    final displayMinutes = todayFocusMinutes > 0 ? todayFocusMinutes : (displayCount * 25);

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    switch (capacity.status) {
      case CapacityStatus.healthy:
        statusColor = AppColors.capacitySafe;
        statusText = '負荷健康';
        statusIcon = Icons.check_circle_outline;
        break;
      case CapacityStatus.moderate:
        statusColor = AppColors.capacityWarning;
        statusText = '接近飽和';
        statusIcon = Icons.info_outline;
        break;
      case CapacityStatus.overloaded:
        statusColor = AppColors.capacityOverloaded;
        final overageHours = (capacity.overageMinutes / 60.0).toStringAsFixed(1);
        statusText = '⚠️ 超載 +${overageHours}h • 建議延後彈性任務';
        statusIcon = Icons.warning_amber_rounded;
        break;
    }

    final double scheduledHours = capacity.totalHours;
    final double capacityHours = capacity.capacityHours;
    final int percentInt = (capacity.workloadPercentage * 100).round();

    final double progressFraction = capacity.workloadPercentage.clamp(0.0, 1.0);
    final double anchorRatio = capacity.totalScheduledMinutes > 0
        ? capacity.anchorMinutes / capacity.totalScheduledMinutes
        : 0.0;
    final double flexibleRatio = capacity.totalScheduledMinutes > 0
        ? capacity.flexibleMinutes / capacity.totalScheduledMinutes
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                '${scheduledHours.toStringAsFixed(1)}h / ${capacityHours.toStringAsFixed(1)}h ($percentInt%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• $statusText',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              // Focus Tally Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '🍅 $displayCount (${displayMinutes}m 專注)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              const Spacer(),
              // Mini Legend
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.anchorEvent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '固定 (${(capacity.anchorMinutes / 60.0).toStringAsFixed(1)}h)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.flexibleTask,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '彈性 (${(capacity.flexibleMinutes / 60.0).toStringAsFixed(1)}h)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stacked Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final activeWidth = totalWidth * progressFraction;
                  final anchorWidth = activeWidth * anchorRatio;
                  final flexibleWidth = activeWidth * flexibleRatio;

                  return Row(
                    children: [
                      if (anchorWidth > 0)
                        Container(
                          width: anchorWidth,
                          height: 6,
                          color: AppColors.anchorEvent,
                        ),
                      if (flexibleWidth > 0)
                        Container(
                          width: flexibleWidth,
                          height: 6,
                          color: capacity.isOverloaded ? AppColors.capacityOverloaded : AppColors.flexibleTask,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
