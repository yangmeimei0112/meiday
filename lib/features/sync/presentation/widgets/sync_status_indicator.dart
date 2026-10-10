import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/sync_state.dart';
import '../providers/sync_providers.dart';
import 'sync_settings_sheet.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncCoordinatorProvider);
    final pendingCount = ref.watch(pendingOutboxCountStreamProvider).value ?? 0;

    return _buildIndicator(context, ref, state, pendingCount);
  }

  Widget _buildIndicator(
    BuildContext context,
    WidgetRef ref,
    SyncState state,
    int pendingCount,
  ) {
    if (state is SyncInProgress) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => SyncSettingsSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '同步中 (${state.processedCount}/${state.totalCount})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state is SyncFailure) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => SyncSettingsSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 14, color: AppColors.danger),
              const SizedBox(width: 6),
              Text(
                pendingCount > 0 ? '$pendingCount 筆待同步' : '離線模式',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default / SyncSuccess / SyncIdle
    final hasPending = pendingCount > 0;
    final color = hasPending ? AppColors.warning : AppColors.success;
    final text = hasPending ? '$pendingCount 筆離線佇列' : '雲端已同步';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (hasPending) {
          final userId = ref.read(authNotifierProvider).currentUser?.id ?? 'guest';
          ref.read(syncCoordinatorProvider.notifier).triggerManualSync(userId);
        } else {
          SyncSettingsSheet.show(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPending ? Icons.sync_problem : Icons.cloud_done,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
