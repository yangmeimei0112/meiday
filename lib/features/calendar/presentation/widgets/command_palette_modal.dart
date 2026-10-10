import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/undo/undo_stack_providers.dart';
import '../../domain/entities/schedule_models.dart';
import '../providers/calendar_providers.dart';

class CommandPaletteAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelect;

  const CommandPaletteAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onSelect,
  });
}

Future<void> showCommandPaletteModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => const CommandPaletteModal(),
  );
}

class CommandPaletteModal extends ConsumerStatefulWidget {
  const CommandPaletteModal({super.key});

  @override
  ConsumerState<CommandPaletteModal> createState() => _CommandPaletteModalState();
}

class _CommandPaletteModalState extends ConsumerState<CommandPaletteModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _selectedIndex = 0;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommandPaletteAction> _getAllActions(BuildContext context) {
    final undoManager = ref.read(undoStackManagerProvider);

    return [
      CommandPaletteAction(
        title: '切換至月視圖 (Month View)',
        subtitle: '展開全月概覽與行程密度標籤',
        icon: Icons.calendar_view_month,
        onSelect: () {
          ref.read(calendarViewModeProvider.notifier).state = CalendarViewMode.month;
        },
      ),
      CommandPaletteAction(
        title: '切換至週視圖 (Week View)',
        subtitle: '7 天多欄時間網格與 15 分鐘吸附排程',
        icon: Icons.calendar_view_week,
        onSelect: () {
          ref.read(calendarViewModeProvider.notifier).state = CalendarViewMode.week;
        },
      ),
      CommandPaletteAction(
        title: '切換至三日視圖 (3-Day View)',
        subtitle: '精簡 3 天時間軸畫布',
        icon: Icons.view_column,
        onSelect: () {
          ref.read(calendarViewModeProvider.notifier).state = CalendarViewMode.threeDay;
        },
      ),
      CommandPaletteAction(
        title: '切換至日視圖 (Day View)',
        subtitle: '單日沉浸式垂直時間軸',
        icon: Icons.calendar_view_day,
        onSelect: () {
          ref.read(calendarViewModeProvider.notifier).state = CalendarViewMode.day;
        },
      ),
      CommandPaletteAction(
        title: '回到今天 (Jump to Today)',
        subtitle: '快速將視角居中於今日',
        icon: Icons.today,
        onSelect: () {
          final now = DateTime.now();
          ref.read(selectedDateProvider.notifier).state = DateTime(now.year, now.month, now.day);
        },
      ),
      CommandPaletteAction(
        title: '放大畫布時間刻度 (+)',
        subtitle: '增加每小時高度以獲得更精細的視角',
        icon: Icons.zoom_in,
        onSelect: () {
          final current = ref.read(hourHeightScaleProvider);
          ref.read(hourHeightScaleProvider.notifier).state = (current + 15).clamp(30.0, 120.0);
        },
      ),
      CommandPaletteAction(
        title: '縮小畫布時間刻度 (-)',
        subtitle: '縮小每小時高度以獲得更廣闊的視角',
        icon: Icons.zoom_out,
        onSelect: () {
          final current = ref.read(hourHeightScaleProvider);
          ref.read(hourHeightScaleProvider.notifier).state = (current - 15).clamp(30.0, 120.0);
        },
      ),
      CommandPaletteAction(
        title: '復原上次操作 (Undo)',
        subtitle: undoManager.canUndo ? (undoManager.lastActionDescription ?? 'Ctrl+Z') : '無可復原的操作',
        icon: Icons.undo,
        onSelect: () {
          if (undoManager.canUndo) {
            undoManager.undo();
          }
        },
      ),
      CommandPaletteAction(
        title: '重做上次操作 (Redo)',
        subtitle: undoManager.canRedo ? (undoManager.nextRedoDescription ?? 'Ctrl+Y') : '無可重做的操作',
        icon: Icons.redo,
        onSelect: () {
          if (undoManager.canRedo) {
            undoManager.redo();
          }
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allActions = _getAllActions(context);

    final filteredActions = _query.isEmpty
        ? allActions
        : allActions.where((action) {
            return action.title.toLowerCase().contains(_query) ||
                action.subtitle.toLowerCase().contains(_query);
          }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 560,
              constraints: const BoxConstraints(maxHeight: 460),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              hintText: '輸入指令、搜尋視圖或操作快捷鍵...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) {
                              if (filteredActions.isNotEmpty) {
                                final action = filteredActions[_selectedIndex.clamp(0, filteredActions.length - 1)];
                                Navigator.of(context).pop();
                                action.onSelect();
                              }
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ESC 關閉',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Actions list
                  Flexible(
                    child: filteredActions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              '無相符的指令或操作',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredActions.length,
                            itemBuilder: (context, index) {
                              final action = filteredActions[index];
                              final isSelected = index == _selectedIndex;

                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  action.onSelect();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(action.icon, size: 18, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              action.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              action.subtitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white60 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 13,
                                        color: isDark ? Colors.white30 : Colors.black26,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
