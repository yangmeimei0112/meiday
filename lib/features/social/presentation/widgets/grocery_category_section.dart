import 'package:flutter/material.dart';
import '../../domain/entities/event_checklist_item.dart';
import '../../domain/entities/grocery_category.dart';
import 'checklist_item_tile.dart';

class GroceryCategorySection extends StatelessWidget {
  final GroceryCategory category;
  final List<EventChecklistItem> items;
  final ValueChanged<EventChecklistItem> onToggle;
  final ValueChanged<EventChecklistItem> onDelete;

  const GroceryCategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final completedCount = items.where((i) => i.isCompleted).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Row(
            children: [
              Text(
                '${category.emoji} ${category.displayName}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$completedCount/${items.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        for (final item in items)
          ChecklistItemTile(
            item: item,
            showCategoryBadge: false,
            onToggle: (completed) => onToggle(item.copyWith(isCompleted: completed)),
            onDelete: () => onDelete(item),
          ),
      ],
    );
  }
}
