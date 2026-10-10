import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/event_checklist_item.dart';
import '../../domain/entities/grocery_category.dart';

class ChecklistItemTile extends StatelessWidget {
  final EventChecklistItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;
  final bool showCategoryBadge;

  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    this.onDelete,
    this.showCategoryBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Checkbox(
        value: item.isCompleted,
        activeColor: AppColors.primary,
        onChanged: (val) {
          if (val != null) onToggle(val);
        },
      ),
      title: Row(
        children: [
          if (showCategoryBadge && item.groceryCategory != GroceryCategory.other) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${item.groceryCategory.emoji} ${item.groceryCategory.displayName}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 13,
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                color: item.isCompleted
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: onDelete,
            )
          : null,
    );
  }
}
