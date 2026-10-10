import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/nlp_parse_result.dart';

class NlpPreviewChips extends StatelessWidget {
  final NlpParseResult result;
  final bool isAnchored;
  final ValueChanged<bool>? onToggleAnchored;

  const NlpPreviewChips({
    super.key,
    required this.result,
    this.isAnchored = false,
    this.onToggleAnchored,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Date / Time Chip
    if (result.isAllDay && result.startTime != null) {
      final dateStr = DateFormat('yyyy/MM/dd').format(result.startTime!);
      chips.add(_buildChip(
        icon: Icons.calendar_today,
        label: '$dateStr 全天',
        color: AppColors.primary,
      ));
    } else if (result.hasTime && result.startTime != null) {
      final dateStr = DateFormat('MM/dd').format(result.startTime!);
      final startStr = DateFormat('HH:mm').format(result.startTime!);
      final endStr = result.endTime != null ? DateFormat('HH:mm').format(result.endTime!) : '';
      chips.add(_buildChip(
        icon: Icons.access_time,
        label: '$dateStr $startStr${endStr.isNotEmpty ? ' - $endStr' : ''}',
        color: AppColors.primary,
      ));
    } else {
      chips.add(_buildChip(
        icon: Icons.inbox,
        label: '靈感備忘 (未定時間)',
        color: Colors.grey,
      ));
    }

    // Duration Chip
    if (!result.isAllDay && result.hasTime) {
      chips.add(_buildChip(
        icon: Icons.timer_outlined,
        label: '${result.durationMinutes} 分鐘',
        color: Colors.teal,
      ));
    }

    // Recurrence Chip
    if (result.hasRecurrence) {
      chips.add(_buildChip(
        icon: Icons.repeat,
        label: _formatRecurrence(result.recurrenceRule!),
        color: Colors.deepPurple,
      ));
    }

    // Tags Chips
    for (final tag in result.tags) {
      chips.add(_buildChip(
        icon: Icons.tag,
        label: tag,
        color: Colors.indigo,
      ));
    }

    // Priority Chip
    if (result.priority > 0) {
      final color = result.priority == 3
          ? Colors.red
          : (result.priority == 2 ? Colors.orange : Colors.blue);
      chips.add(_buildChip(
        icon: Icons.flag,
        label: 'P${result.priority}',
        color: color,
      ));
    }

    // Track Chip (Toggleable)
    chips.add(
      InkWell(
        onTap: () => onToggleAnchored?.call(!isAnchored),
        borderRadius: BorderRadius.circular(16),
        child: _buildChip(
          icon: isAnchored ? Icons.anchor : Icons.waves,
          label: isAnchored ? '固定錨定 (Track 1)' : '彈性區塊 (Track 2)',
          color: isAnchored ? AppColors.anchorEvent : AppColors.flexibleTask,
          interactive: true,
        ),
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    bool interactive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: interactive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecurrence(String rrule) {
    if (rrule.contains('FREQ=DAILY')) return '每天';
    if (rrule.contains('BYDAY=MO,TU,WE,TH,FR')) return '每個工作日';
    if (rrule.contains('BYDAY=MO')) return '每週一';
    if (rrule.contains('BYDAY=TU')) return '每週二';
    if (rrule.contains('BYDAY=WE')) return '每週三';
    if (rrule.contains('BYDAY=TH')) return '每週四';
    if (rrule.contains('BYDAY=FR')) return '每週五';
    if (rrule.contains('BYDAY=SA')) return '每週六';
    if (rrule.contains('BYDAY=SU')) return '每週日';
    if (rrule.contains('FREQ=WEEKLY')) return '每週';
    if (rrule.contains('FREQ=MONTHLY')) return '每月';
    if (rrule.contains('FREQ=YEARLY')) return '每年';
    return '重複排程';
  }
}
