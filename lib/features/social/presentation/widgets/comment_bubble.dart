import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/event_comment.dart';

class CommentBubble extends StatelessWidget {
  final EventComment comment;
  final String currentUserId;
  final VoidCallback? onDelete;

  const CommentBubble({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onDelete,
  });

  bool get isCurrentUser =>
      comment.userId == currentUserId ||
      (currentUserId == 'guest' && comment.userId == 'guest');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
              child: Text(
                comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isCurrentUser ? 12 : 2),
                  bottomRight: Radius.circular(isCurrentUser ? 2 : 12),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        comment.authorName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCurrentUser
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(comment.createdAt),
                    style: TextStyle(
                      fontSize: 9,
                      color: isCurrentUser
                          ? Colors.white70
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
