import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../application/commands/create_event_command.dart';
import '../../application/commands/move_event_command.dart';
import '../../application/commands/resize_event_command.dart';
import '../../application/undo/undo_stack_providers.dart';
import '../../domain/entities/schedule_models.dart';
import '../providers/calendar_providers.dart';

class ConflictProposalBanner extends ConsumerWidget {
  const ConflictProposalBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflict = ref.watch(activeConflictProvider);
    if (conflict == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockedTitle = conflict.blockedEvent.title;
    final anchorTitle = conflict.collidingAnchor.title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.capacityWarning.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.capacityWarning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ 「$blockedTitle」與「$anchorTitle」發生排程衝突 (重疊 ${conflict.overlapMinutes} 分鐘)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '忽略此衝突',
                      onPressed: () {
                        ref.read(activeConflictProvider.notifier).state = null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final proposal in conflict.proposals)
                      _ProposalChip(
                        proposal: proposal,
                        conflict: conflict,
                      ),
                    ActionChip(
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                      label: Text(
                        '忽略/重疊',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      onPressed: () {
                        ref.read(activeConflictProvider.notifier).state = null;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProposalChip extends ConsumerWidget {
  final ProposalAlternative proposal;
  final ScheduleConflict conflict;

  const _ProposalChip({
    required this.proposal,
    required this.conflict,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionChip(
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      avatar: const Icon(Icons.auto_fix_high, size: 14, color: AppColors.primary),
      label: Text(
        proposal.label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      onPressed: () async {
        final db = ref.read(appDatabaseProvider);
        final undoManager = ref.read(undoStackManagerProvider);
        final blocked = conflict.blockedEvent;

        switch (proposal.type) {
          case ProposalAlternativeType.shiftPastAnchor:
            if (proposal.newStartTime != null && proposal.newEndTime != null) {
              final cmd = MoveEventCommand(
                id: UuidUtils.generate(),
                description: '順延「${blocked.title}」至會議後',
                timestamp: DateTime.now(),
                eventId: blocked.id,
                previousStartTime: blocked.startTime,
                previousEndTime: blocked.endTime,
                targetStartTime: proposal.newStartTime,
                targetEndTime: proposal.newEndTime,
                database: db,
                userId: blocked.userId,
              );
              await undoManager.execute(cmd);
            }
            break;

          case ProposalAlternativeType.trimBuffer:
            if (proposal.compressedDurationMinutes != null && proposal.proposedEndTime != null) {
              final cmd = ResizeEventCommand(
                id: UuidUtils.generate(),
                description: '縮減「${blocked.title}」工時至 ${proposal.compressedDurationMinutes} 分鐘',
                timestamp: DateTime.now(),
                eventId: blocked.id,
                previousStartTime: blocked.startTime,
                previousEndTime: blocked.endTime,
                previousEstimatedMinutes: blocked.estimatedMinutes,
                targetStartTime: blocked.startTime,
                targetEndTime: proposal.proposedEndTime,
                targetEstimatedMinutes: proposal.compressedDurationMinutes!,
                database: db,
                userId: blocked.userId,
              );
              await undoManager.execute(cmd);
            }
            break;

          case ProposalAlternativeType.splitBlock:
            if (proposal.part1 != null && proposal.part2 != null) {
              // Resize part 1
              final resizeCmd = ResizeEventCommand(
                id: UuidUtils.generate(),
                description: '拆分「${blocked.title}」第 1 階段',
                timestamp: DateTime.now(),
                eventId: blocked.id,
                previousStartTime: blocked.startTime,
                previousEndTime: blocked.endTime,
                previousEstimatedMinutes: blocked.estimatedMinutes,
                targetStartTime: proposal.part1!.startTime,
                targetEndTime: proposal.part1!.endTime,
                targetEstimatedMinutes: proposal.part1!.estimatedMinutes,
                database: db,
                userId: blocked.userId,
              );
              await undoManager.execute(resizeCmd);

              // Create part 2
              final createCmd = CreateEventCommand(
                id: UuidUtils.generate(),
                description: '拆分「${blocked.title}」第 2 階段',
                timestamp: DateTime.now(),
                eventCompanion: proposal.part2!.toCompanion(),
                database: db,
                userId: blocked.userId,
              );
              await undoManager.execute(createCmd);
            }
            break;

          case ProposalAlternativeType.alternativeSlot:
            if (proposal.slotStartTime != null && proposal.slotEndTime != null) {
              final cmd = MoveEventCommand(
                id: UuidUtils.generate(),
                description: '移至空檔時段「${blocked.title}」',
                timestamp: DateTime.now(),
                eventId: blocked.id,
                previousStartTime: blocked.startTime,
                previousEndTime: blocked.endTime,
                targetStartTime: proposal.slotStartTime,
                targetEndTime: proposal.slotEndTime,
                database: db,
                userId: blocked.userId,
              );
              await undoManager.execute(cmd);
            }
            break;
        }

        ref.read(activeConflictProvider.notifier).state = null;
      },
    );
  }
}
