import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/space_providers.dart';

class SpaceDrawer extends ConsumerStatefulWidget {
  final String userId;

  const SpaceDrawer({
    super.key,
    this.userId = 'guest',
  });

  @override
  ConsumerState<SpaceDrawer> createState() => _SpaceDrawerState();
}

class _SpaceDrawerState extends ConsumerState<SpaceDrawer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spaceRepositoryProvider).ensureDefaultSpacesSeeded(userId: widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacesAsync = ref.watch(spacesStreamProvider);
    final activeIds = ref.watch(activeSpaceIdsProvider);
    final notifier = ref.read(activeSpaceIdsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : AppColors.primary.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 20,
                    child: Icon(Icons.hub_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ChronoHub 空間',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.userId == 'guest' ? '訪客模式 (本機隔離)' : '使用者: ${widget.userId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Spaces Section Header & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Text(
                    '日曆空間',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  spacesAsync.maybeWhen(
                    data: (spaces) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => notifier.selectAll(spaces),
                          child: const Text('全選', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => notifier.clearAll(),
                          child: const Text('清空', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Spaces List
            Expanded(
              child: spacesAsync.when(
                data: (spaces) {
                  if (spaces.isEmpty) {
                    return Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('初始化預設空間'),
                        onPressed: () {
                          ref.read(spaceRepositoryProvider).ensureDefaultSpacesSeeded(userId: widget.userId);
                        },
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: spaces.length,
                    itemBuilder: (context, index) {
                      final space = spaces[index];
                      final isSelected = activeIds.contains(space.id);

                      return InkWell(
                        onTap: () {
                          // Solo-isolation mode on row tap
                          notifier.isolateSpace(space.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: space.colorValue.withValues(alpha: 0.15),
                                  border: Border.all(color: space.colorValue, width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  space.icon ?? '📅',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  space.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Checkbox(
                                value: isSelected,
                                activeColor: space.colorValue,
                                onChanged: (val) {
                                  notifier.toggleSpace(space.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('載入失敗: $err')),
              ),
            ),

            const Divider(height: 1),

            // Add Space Button
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增空間'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _showAddSpaceDialog(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSpaceDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    int selectedColor = AppColors.spacePersonal.toARGB32();
    String selectedIcon = '🏷️';
    String selectedType = 'project';

    final iconOptions = ['🏷️', '🎯', '📚', '🚀', '🎨', '✈️', '🏋️', '🌟'];
    final colorOptions = [
      AppColors.spacePersonal.toARGB32(),
      AppColors.spacePartner.toARGB32(),
      AppColors.spaceFamily.toARGB32(),
      AppColors.spaceWork.toARGB32(),
      0xFF10B981, // Emerald
      0xFF8B5CF6, // Purple
      0xFFF97316, // Orange
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('新增自訂日曆空間'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '空間名稱',
                        hintText: '例：健身俱樂部、讀書會',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('選擇圖示：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: iconOptions.map((emoji) {
                        final isChosen = selectedIcon == emoji;
                        return ChoiceChip(
                          label: Text(emoji, style: const TextStyle(fontSize: 16)),
                          selected: isChosen,
                          onSelected: (_) => setDialogState(() => selectedIcon = emoji),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('選擇主題色：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: colorOptions.map((c) {
                        final isChosen = selectedColor == c;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isChosen ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isChosen
                                  ? [BoxShadow(color: Color(c), blurRadius: 6)]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    await ref.read(spaceRepositoryProvider).createSpace(
                          name: name,
                          type: selectedType,
                          color: selectedColor,
                          icon: selectedIcon,
                          userId: widget.userId,
                        );

                    if (context.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                  child: const Text('建立'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
