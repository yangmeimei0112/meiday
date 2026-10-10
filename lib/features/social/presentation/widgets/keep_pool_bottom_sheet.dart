import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/keep_item.dart';
import '../providers/keep_providers.dart';
import 'keep_item_card.dart';

class KeepPoolBottomSheet extends ConsumerStatefulWidget {
  final String userId;

  const KeepPoolBottomSheet({
    super.key,
    this.userId = 'guest',
  });

  @override
  ConsumerState<KeepPoolBottomSheet> createState() => _KeepPoolBottomSheetState();
}

class _KeepPoolBottomSheetState extends ConsumerState<KeepPoolBottomSheet> {
  final TextEditingController _titleController = TextEditingController();

  void _addItem() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final item = KeepItem(
      id: UuidUtils.generate(),
      userId: widget.userId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );

    ref.read(keepRepositoryProvider).createKeepItem(item);
    _titleController.clear();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(activeKeepItemsStreamProvider(widget.userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
                const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('靈感備忘池 (Keep)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Input field
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                    decoration: InputDecoration(
                      hintText: '記錄新靈感 / 未定待辦...',
                      hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: _addItem,
                ),
              ],
            ),
          ),

          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '靈感池目前是空的',
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return KeepItemCard(
                      item: item,
                      onDelete: () {
                        ref.read(keepRepositoryProvider).deleteKeepItem(item.id);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('載入失敗: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
