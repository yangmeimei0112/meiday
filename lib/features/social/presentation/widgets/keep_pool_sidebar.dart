import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../domain/entities/keep_item.dart';
import '../providers/keep_providers.dart';
import 'keep_item_card.dart';

class KeepPoolSidebar extends ConsumerStatefulWidget {
  final String userId;
  final VoidCallback? onClose;

  const KeepPoolSidebar({
    super.key,
    this.userId = 'guest',
    this.onClose,
  });

  @override
  ConsumerState<KeepPoolSidebar> createState() => _KeepPoolSidebarState();
}

class _KeepPoolSidebarState extends ConsumerState<KeepPoolSidebar> {
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
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  '靈感池 (Keep)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Quick add input
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                    decoration: InputDecoration(
                      hintText: '記錄新靈感 / 未定待辦...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: _addItem,
                ),
              ],
            ),
          ),

          // Tip Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '💡 長按卡片拖拽至時間軸直接排程',
              style: TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ),

          // Items List
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '靈感池目前是空的\n隨手記錄點子，隨時拖入日曆！',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                      ),
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
