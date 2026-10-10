import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/event_checklist_item.dart';
import '../../domain/entities/grocery_category.dart';
import '../providers/in_event_providers.dart';
import '../widgets/attachment_grid_tile.dart';
import '../widgets/checklist_item_tile.dart';
import '../widgets/comment_bubble.dart';
import '../widgets/comment_input_bar.dart';
import '../widgets/grocery_category_section.dart';

class EventDetailSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String userId;

  const EventDetailSheet({
    super.key,
    required this.eventId,
    this.userId = 'guest',
  });

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _groceryMode = false;
  final TextEditingController _quickAddChecklistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickAddChecklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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

          // Segmented Three-fold Tab Bar ("三折頁")
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: '討論留言'),
              Tab(icon: Icon(Icons.checklist_outlined, size: 20), text: '分工清單'),
              Tab(icon: Icon(Icons.photo_library_outlined, size: 20), text: '相片附件'),
            ],
          ),
          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDiscussionTab(isDark),
                _buildChecklistTab(isDark),
                _buildAttachmentsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionTab(bool isDark) {
    final commentsAsync = ref.watch(eventCommentsStreamProvider(widget.eventId));

    return Column(
      children: [
        Expanded(
          child: commentsAsync.when(
            data: (comments) {
              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        '尚無討論留言，快發起第一則話題！',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return CommentBubble(
                    comment: comment,
                    currentUserId: widget.userId,
                    onDelete: () {
                      ref.read(commentRepositoryProvider).deleteComment(
                            commentId: comment.id,
                            userId: widget.userId,
                          );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('載入失敗: $err')),
          ),
        ),
        CommentInputBar(
          onSend: (content) {
            ref.read(commentRepositoryProvider).postComment(
                  eventId: widget.eventId,
                  content: content,
                  authorName: widget.userId == 'guest' ? '訪客' : '我',
                  userId: widget.userId,
                );
          },
        ),
      ],
    );
  }

  Widget _buildChecklistTab(bool isDark) {
    final checklistAsync = ref.watch(eventChecklistStreamProvider(widget.eventId));

    return Column(
      children: [
        // Top Toolbar: Mode Switcher & Progress Bar
        checklistAsync.maybeWhen(
          data: (items) {
            final total = items.length;
            final completed = items.where((i) => i.isCompleted).length;
            final percent = total > 0 ? (completed / total) : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '進度: $completed/$total (${(percent * 100).toInt()}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('待辦')),
                          ButtonSegment(value: true, label: Text('🛒 採買')),
                        ],
                        selected: {_groceryMode},
                        onSelectionChanged: (val) {
                          setState(() => _groceryMode = val.first);
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: percent,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // Quick add item bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickAddChecklistController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (text) => _addNewChecklistItem(text),
                  decoration: InputDecoration(
                    hintText: _groceryMode ? '新增採買項目 (例：鮮奶、蘋果)...' : '新增代辦任務...',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                onPressed: () => _addNewChecklistItem(_quickAddChecklistController.text),
              ),
            ],
          ),
        ),

        // Checklist Items List
        Expanded(
          child: checklistAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    '尚無清單項目',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                );
              }

              if (_groceryMode) {
                // Group by GroceryCategory
                final grouped = <GroceryCategory, List<EventChecklistItem>>{};
                for (final item in items) {
                  grouped.putIfAbsent(item.groceryCategory, () => []).add(item);
                }

                return ListView(
                  children: [
                    for (final entry in grouped.entries)
                      GroceryCategorySection(
                        category: entry.key,
                        items: entry.value,
                        onToggle: (updated) {
                          ref.read(checklistRepositoryProvider).toggleItem(
                                itemId: updated.id,
                                isCompleted: updated.isCompleted,
                                userId: widget.userId,
                              );
                        },
                        onDelete: (item) {
                          ref.read(checklistRepositoryProvider).deleteItem(
                                itemId: item.id,
                                userId: widget.userId,
                              );
                        },
                      ),
                  ],
                );
              } else {
                // Reorderable list in standard task mode
                return ReorderableListView.builder(
                  itemCount: items.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final list = List<EventChecklistItem>.from(items);
                    final moved = list.removeAt(oldIndex);
                    list.insert(newIndex, moved);
                    ref.read(checklistRepositoryProvider).reorderItems(
                          eventId: widget.eventId,
                          orderedItemIds: list.map((i) => i.id).toList(),
                          userId: widget.userId,
                        );
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ChecklistItemTile(
                      key: ValueKey(item.id),
                      item: item,
                      onToggle: (completed) {
                        ref.read(checklistRepositoryProvider).toggleItem(
                              itemId: item.id,
                              isCompleted: completed,
                              userId: widget.userId,
                            );
                      },
                      onDelete: () {
                        ref.read(checklistRepositoryProvider).deleteItem(
                              itemId: item.id,
                              userId: widget.userId,
                            );
                      },
                    );
                  },
                );
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('載入失敗: $err')),
          ),
        ),
      ],
    );
  }

  void _addNewChecklistItem(String text) {
    final title = text.trim();
    if (title.isEmpty) return;

    ref.read(checklistRepositoryProvider).addItem(
          eventId: widget.eventId,
          title: title,
          userId: widget.userId,
        );
    _quickAddChecklistController.clear();
  }

  Widget _buildAttachmentsTab(bool isDark) {
    final attachmentsAsync = ref.watch(eventAttachmentsStreamProvider(widget.eventId));

    return Column(
      children: [
        // Add attachment button bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const Text('相片清單', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('新增相片'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _addSampleAttachment(),
              ),
            ],
          ),
        ),

        Expanded(
          child: attachmentsAsync.when(
            data: (attachments) {
              if (attachments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        '尚無相片附件，點擊上方按鈕新增',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final att = attachments[index];
                  return AttachmentGridTile(
                    attachment: att,
                    onDelete: () {
                      ref.read(attachmentRepositoryProvider).deleteAttachment(
                            attachmentId: att.id,
                            userId: widget.userId,
                          );
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
    );
  }

  void _addSampleAttachment() {
    final now = DateTime.now();
    final sampleFileName = 'photo_${now.millisecondsSinceEpoch}.jpg';
    final repo = ref.read(attachmentRepositoryProvider);
    final localPath = repo.getLocalFilePath(widget.eventId, 'temp', 'jpg');

    repo.addAttachment(
      eventId: widget.eventId,
      userId: widget.userId,
      fileName: sampleFileName,
      fileUrl: localPath,
      fileType: 'image/jpeg',
      fileSize: 1024 * 342, // ~342 KB
    );
  }
}
