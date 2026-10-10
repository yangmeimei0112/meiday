import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/optimal_meeting_slot.dart';
import '../providers/heatmap_providers.dart';

class OptimalMeetingSheet extends ConsumerStatefulWidget {
  final DateTime targetDate;
  final ValueChanged<OptimalMeetingSlot>? onSelectSlot;

  const OptimalMeetingSheet({
    super.key,
    required this.targetDate,
    this.onSelectSlot,
  });

  @override
  ConsumerState<OptimalMeetingSheet> createState() => _OptimalMeetingSheetState();
}

class _OptimalMeetingSheetState extends ConsumerState<OptimalMeetingSheet> {
  int _selectedDuration = 30; // minutes

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(dayAvailabilitySlotsProvider(widget.targetDate));
    final finder = ref.watch(optimalMeetingFinderProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final candidates = finder.findOptimalSlots(
      availabilitySlots: slots,
      durationMinutes: _selectedDuration,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.flash_on_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  '最佳空檔探測器 (Optimal Meeting)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Duration choice chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text('會議時長：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [15, 30, 45, 60, 90].map((dur) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$dur 分鐘'),
                            selected: _selectedDuration == dur,
                            onSelected: (_) => setState(() => _selectedDuration = dur),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: candidates.isEmpty
              ? Center(
                  child: Text(
                    '當日無合適的連續時段',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return _buildCandidateCard(candidate, isDark);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(OptimalMeetingSlot slot, bool isDark) {
    final startTimeStr = _formatTime(slot.startTime);
    final endTimeStr = _formatTime(slot.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: slot.isZeroConflict
            ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: slot.isZeroConflict
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: slot.isZeroConflict ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: slot.isZeroConflict ? const Color(0xFF10B981) : Colors.amber,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              slot.isZeroConflict ? '🟢 推薦' : '🟡 有衝突',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startTimeStr - $endTimeStr',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.isZeroConflict
                      ? '100% 全員皆有空'
                      : '最大衝突: ${slot.maxConflictCount} 人忙碌',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: slot.isZeroConflict ? const Color(0xFF10B981) : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSelectSlot?.call(slot);
            },
            child: const Text('選用時段'),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
