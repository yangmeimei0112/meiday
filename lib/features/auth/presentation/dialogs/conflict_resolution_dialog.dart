import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/glassmorphism.dart';
import '../../../../core/database/migrations/migration_models.dart';

class ConflictResolutionDialog extends StatelessWidget {
  const ConflictResolutionDialog({super.key});

  static Future<MigrationMode?> show(BuildContext context) {
    return showDialog<MigrationMode>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ConflictResolutionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        decoration: GlassmorphismStyles.glassDecoration(
          context: context,
          borderRadius: 24,
          opacity: 0.95,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sync_problem_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '帳號資料衝突裁決',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '偵測到訪客本機草稿與雲端既有資料',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '您在訪客模式下建立了本地行程，同時您的帳號已存在雲端歷史資料。請選擇資料合併策略：',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Option 1: Merge Local (Primary Action)
            _StrategyCard(
              title: '合併本地行程至個人日曆',
              subtitle: '將訪客建立的行程與未定靈感收錄至個人日曆，並同步至雲端（既有雲端行程完整保留）。',
              icon: Icons.merge_type_rounded,
              iconColor: AppColors.primary,
              borderColor: AppColors.primary.withValues(alpha: 0.4),
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              onTap: () => Navigator.of(context).pop(MigrationMode.mergeLocal),
            ),
            const SizedBox(height: 12),

            // Option 2: Discard Local (Secondary Action)
            _StrategyCard(
              title: '放棄本地草稿，以雲端為主',
              subtitle: '捨棄訪客建立的本機草稿，直接載入雲端既有帳號資料。',
              icon: Icons.cloud_download_outlined,
              iconColor: theme.colorScheme.error,
              borderColor: theme.colorScheme.error.withValues(alpha: 0.3),
              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.05),
              onTap: () => Navigator.of(context).pop(MigrationMode.discardLocal),
            ),
            const SizedBox(height: 16),

            // Option 3: Cancel (Stay in guest mode)
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                '取消並返回訪客模式',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrategyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _StrategyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
