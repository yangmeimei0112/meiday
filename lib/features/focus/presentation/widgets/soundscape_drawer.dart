import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/soundscape_preset.dart';
import '../providers/focus_providers.dart';

class SoundscapeDrawer extends ConsumerWidget {
  const SoundscapeDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SoundscapeDrawer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soundscapeManager = ref.watch(soundscapeManagerProvider);
    final state = soundscapeManager.state;

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.graphic_eq, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  '環境白噪音 (Soundscapes)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preset Selection Grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: SoundscapePreset.values.map((preset) {
                final isSelected = state.currentPreset == preset;
                return ChoiceChip(
                  avatar: Text(preset.emoji, style: const TextStyle(fontSize: 16)),
                  label: Text(preset.displayName),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(soundscapeManagerProvider.notifier).selectPreset(preset);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Play / Pause Controls
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(state.isPlaying ? '暫停播放' : '開始播放'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final mgr = ref.read(soundscapeManagerProvider.notifier);
                    if (state.isPlaying) {
                      mgr.pause();
                    } else {
                      mgr.play();
                    }
                  },
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                  onPressed: state.isPlaying
                      ? () => ref.read(soundscapeManagerProvider.notifier).stop()
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Volume Slider
            Row(
              children: [
                const Icon(Icons.volume_down, size: 20),
                Expanded(
                  child: Slider(
                    value: state.volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(state.volume * 100).toInt()}%',
                    onChanged: (val) {
                      ref.read(soundscapeManagerProvider.notifier).setVolume(val);
                    },
                  ),
                ),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),
            const SizedBox(height: 8),

            // Auto-Pause on Break Switch
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('番茄鐘休息時自動暫停', style: TextStyle(fontSize: 13)),
                subtitle: const Text('專注結束時淡出音樂，進入休息', style: TextStyle(fontSize: 11)),
                value: state.autoPauseOnBreak,
                onChanged: (val) {
                  ref.read(soundscapeManagerProvider.notifier).setAutoPauseOnBreak(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
