import 'package:flutter/material.dart';
import '../../domain/entities/keep_item.dart';

class KeepItemCard extends StatelessWidget {
  final KeepItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const KeepItemCard({
    super.key,
    required this.item,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.color != null
            ? Color(item.color!).withValues(alpha: isDark ? 0.25 : 0.15)
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.color != null
              ? Color(item.color!)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item.priority != KeepPriority.none) ...[
                const SizedBox(width: 4),
                _buildPriorityBadge(item.priority),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: item.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$t',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );

    return LongPressDraggable<KeepItem>(
      data: item,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
        child: SizedBox(
          width: 220,
          child: Opacity(
            opacity: 0.9,
            child: cardContent,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: cardContent,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: cardContent,
      ),
    );
  }

  Widget _buildPriorityBadge(KeepPriority priority) {
    Color color;
    String label;
    switch (priority) {
      case KeepPriority.high:
        color = Colors.red;
        label = '高';
        break;
      case KeepPriority.medium:
        color = Colors.amber;
        label = '中';
        break;
      case KeepPriority.low:
        color = Colors.blue;
        label = '低';
        break;
      case KeepPriority.none:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
