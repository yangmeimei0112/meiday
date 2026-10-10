import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../../capture/application/ocr_event_pipeline.dart';
import '../../../capture/presentation/providers/capture_providers.dart';
import '../../../capture/presentation/widgets/ocr_capture_dialog.dart';
import '../../../capture/presentation/widgets/quick_capture_modal.dart';
import '../../../focus/presentation/widgets/pomodoro_focus_sheet.dart';
import '../../../focus/presentation/widgets/pomodoro_pip_widget.dart';
import '../../../social/domain/entities/optimal_meeting_slot.dart';
import '../../../social/presentation/providers/heatmap_providers.dart';
import '../../../social/presentation/providers/keep_providers.dart';
import '../../../social/presentation/providers/space_providers.dart';
import '../../../social/presentation/sheets/optimal_meeting_sheet.dart';
import '../../../social/presentation/widgets/keep_pool_bottom_sheet.dart';
import '../../../social/presentation/widgets/keep_pool_sidebar.dart';
import '../../../social/presentation/widgets/space_drawer.dart';
import '../../application/commands/create_event_command.dart';
import '../../application/undo/undo_stack_providers.dart';
import '../../domain/entities/schedule_models.dart';
import '../providers/calendar_providers.dart';
import '../shortcuts/calendar_shortcuts_wrapper.dart';
import '../widgets/capacity_bar.dart';
import '../widgets/command_palette_modal.dart';
import '../widgets/conflict_proposal_banner.dart';
import '../widgets/month_view_grid.dart';
import '../widgets/time_grid_canvas.dart';
import '../../../sync/presentation/widgets/sync_status_indicator.dart';

class CalendarScreen extends ConsumerWidget {
  final bool isGuest;

  const CalendarScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(calendarViewModeProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final undoManager = ref.watch(undoStackManagerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeepPoolOpen = ref.watch(isKeepPoolOpenProvider);

    return CalendarShortcutsWrapper(
      child: Scaffold(
        drawer: const SpaceDrawer(userId: 'guest'),
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // Calendar Screen App Bar / Header
              _buildHeader(
                  context, ref, selectedDate, viewMode, undoManager, isDark),

              // Daily Capacity Bar
              const CapacityBar(),

              // Canvas Body with Floating Conflict Banner & Optional Keep Sidebar
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // Main Canvas View
                          _buildCanvasBody(viewMode),

                          // Floating Conflict Proposal Banner
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: ConflictProposalBanner(),
                          ),

                          // Floating Pomodoro PIP Widget
                          const Positioned(
                            bottom: 20,
                            right: 20,
                            child: PomodoroPipWidget(),
                          ),
                        ],
                      ),
                    ),
                    if (isKeepPoolOpen)
                      KeepPoolSidebar(
                        userId: isGuest ? 'guest' : 'guest',
                        onClose: () => ref
                            .read(isKeepPoolOpenProvider.notifier)
                            .state = false,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasBody(CalendarViewMode viewMode) {
    switch (viewMode) {
      case CalendarViewMode.month:
        return const MonthViewGrid();
      case CalendarViewMode.week:
        return const TimeGridCanvas(columnCount: 7);
      case CalendarViewMode.threeDay:
        return const TimeGridCanvas(columnCount: 3);
      case CalendarViewMode.day:
        return const TimeGridCanvas(columnCount: 1);
    }
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
    CalendarViewMode viewMode,
    dynamic undoManager,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    // Space Drawer hamburger button
                    Builder(
                      builder: (scaffoldCtx) => IconButton(
                        icon: const Icon(Icons.menu, size: 20),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        tooltip: '日曆空間 (Spaces)',
                        onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Navigation controls: Prev, Today, Next
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '前一時段',
                      onPressed: () {
                        _navigateDate(ref, selectedDate, viewMode, -1);
                      },
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final now = DateTime.now();
                        ref.read(selectedDateProvider.notifier).state =
                            DateTime(now.year, now.month, now.day);
                      },
                      child: const Text('今日',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '後一時段',
                      onPressed: () {
                        _navigateDate(ref, selectedDate, viewMode, 1);
                      },
                    ),
                    const SizedBox(width: 8),

                    // Date / Month title display
                    Text(
                      '${selectedDate.year}年 ${selectedDate.month}月',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    // View mode segment switch
                    SegmentedButton<CalendarViewMode>(
                      segments: const [
                        ButtonSegment(
                            value: CalendarViewMode.month, label: Text('月')),
                        ButtonSegment(
                            value: CalendarViewMode.week, label: Text('週')),
                        ButtonSegment(
                            value: CalendarViewMode.threeDay,
                            label: Text('3日')),
                        ButtonSegment(
                            value: CalendarViewMode.day, label: Text('日')),
                      ],
                      selected: {viewMode},
                      onSelectionChanged: (newSelection) {
                        ref.read(calendarViewModeProvider.notifier).state =
                            newSelection.first;
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Undo / Redo controls
                    IconButton(
                      icon: const Icon(Icons.undo, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: undoManager.canUndo
                          ? '復原 (${undoManager.lastActionDescription ?? 'Ctrl+Z'})'
                          : '無可復原項目',
                      onPressed:
                          undoManager.canUndo ? () => undoManager.undo() : null,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.redo, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: undoManager.canRedo
                          ? '重做 (${undoManager.nextRedoDescription ?? 'Ctrl+Y'})'
                          : '無可重做項目',
                      onPressed:
                          undoManager.canRedo ? () => undoManager.redo() : null,
                    ),

                    const SizedBox(width: 6),

                    // Multi-person availability heatmap toggle
                    Consumer(
                      builder: (context, ref, _) {
                        final isHeatmap = ref.watch(isHeatmapActiveProvider);
                        return IconButton(
                          icon: Icon(
                            isHeatmap
                                ? Icons.local_fire_department
                                : Icons.local_fire_department_outlined,
                            size: 20,
                            color: isHeatmap ? Colors.amber : null,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: '多人空檔熱力圖',
                          onPressed: () => ref
                              .read(isHeatmapActiveProvider.notifier)
                              .state = !isHeatmap,
                        );
                      },
                    ),

                    const SizedBox(width: 6),

                    // Optimal meeting finder launcher
                    IconButton(
                      icon: const Icon(Icons.flash_on_outlined, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '最佳空檔探測器',
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => OptimalMeetingSheet(
                            targetDate: selectedDate,
                            onSelectSlot: (slot) =>
                                _scheduleFromOptimalSlot(context, ref, slot),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 6),

                    // Keep Pool toggle button
                    Consumer(
                      builder: (context, ref, _) {
                        final isKeepOpen = ref.watch(isKeepPoolOpenProvider);
                        return IconButton(
                          icon: Icon(
                            isKeepOpen
                                ? Icons.lightbulb
                                : Icons.lightbulb_outline,
                            size: 20,
                            color: isKeepOpen ? Colors.amber : null,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: '靈感備忘池 (Keep)',
                          onPressed: () {
                            final next = !isKeepOpen;
                            ref.read(isKeepPoolOpenProvider.notifier).state =
                                next;
                            if (next && constraints.maxWidth < 700) {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const KeepPoolBottomSheet(),
                              );
                            }
                          },
                        );
                      },
                    ),

                    const SizedBox(width: 6),

                    // Command Palette hotkey button
                    IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '命令面板 (Ctrl+K)',
                      onPressed: () => showCommandPaletteModal(context),
                    ),

                    const SizedBox(width: 6),

                    // NLP Quick Capture button
                    IconButton(
                      icon: const Icon(Icons.auto_awesome,
                          color: AppColors.primary, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: 'NLP 智慧速記 (Win+Shift+C)',
                      onPressed: () => QuickCaptureModal.show(context,
                          userId: isGuest ? 'guest' : 'guest'),
                    ),

                    const SizedBox(width: 6),

                    // OCR Scan button
                    IconButton(
                      icon: const Icon(Icons.document_scanner, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: 'OCR 拍照/截圖轉日程',
                      onPressed: () => _triggerOcrCapture(context, ref),
                    ),

                    const SizedBox(width: 6),

                    // Pomodoro Focus launcher
                    IconButton(
                      icon: const Icon(Icons.timer_outlined, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '番茄鐘專注 (Pomodoro)',
                      onPressed: () => PomodoroFocusSheet.show(context),
                    ),

                    const SizedBox(width: 6),

                    // Quick Add Event button
                    IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: AppColors.primary, size: 22),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '新增日程 / GTD 任務',
                      onPressed: () =>
                          _showQuickAddDialog(context, ref, selectedDate),
                    ),

                    const SizedBox(width: 8),

                    // Cloud sync status & offline queue indicator
                    const SyncStatusIndicator(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _triggerOcrCapture(BuildContext context, WidgetRef ref) async {
    final ocrService = ref.read(ocrServiceProvider);
    final nlpParser = ref.read(nlpParserProvider);
    final pipeline =
        OcrEventPipeline(ocrService: ocrService, nlpParser: nlpParser);

    // Default simulation bytes for OCR extraction
    final bytes =
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    try {
      final draft = await pipeline.processImage(bytes);
      if (context.mounted) {
        await OcrCaptureDialog.show(context,
            draft: draft, userId: isGuest ? 'guest' : 'guest');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR 識別失敗：$e')),
        );
      }
    }
  }

  void _navigateDate(
      WidgetRef ref, DateTime current, CalendarViewMode mode, int direction) {
    DateTime nextDate;
    switch (mode) {
      case CalendarViewMode.month:
        nextDate = DateTime(current.year, current.month + direction, 1);
        break;
      case CalendarViewMode.week:
        nextDate = current.add(Duration(days: 7 * direction));
        break;
      case CalendarViewMode.threeDay:
        nextDate = current.add(Duration(days: 3 * direction));
        break;
      case CalendarViewMode.day:
        nextDate = current.add(Duration(days: 1 * direction));
        break;
    }
    ref.read(selectedDateProvider.notifier).state = nextDate;
  }

  void _showQuickAddDialog(
      BuildContext context, WidgetRef ref, DateTime baseDate) {
    final titleController = TextEditingController();
    bool isAnchored = false;
    int duration = 60;
    int startHour = 9;
    final selectedSpaceIds = <String>{};

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('新增日程'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '行程名稱',
                        hintText: '例：專案同步會議、寫報告',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('類型：'),
                        ChoiceChip(
                          label: const Text('固定錨定 (Track 1)'),
                          selected: isAnchored,
                          onSelected: (val) =>
                              setDialogState(() => isAnchored = true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('彈性區塊 (Track 2)'),
                          selected: !isAnchored,
                          onSelected: (val) =>
                              setDialogState(() => isAnchored = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('開始時間：'),
                        DropdownButton<int>(
                          value: startHour,
                          items: List.generate(
                              24,
                              (i) => DropdownMenuItem(
                                  value: i, child: Text('$i:00'))),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => startHour = val);
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        const Text('時長：'),
                        DropdownButton<int>(
                          value: duration,
                          items: const [
                            DropdownMenuItem(value: 30, child: Text('30 分鐘')),
                            DropdownMenuItem(value: 60, child: Text('60 分鐘')),
                            DropdownMenuItem(value: 90, child: Text('90 分鐘')),
                            DropdownMenuItem(value: 120, child: Text('120 分鐘')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => duration = val);
                            }
                          },
                        ),
                      ],
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final spaces =
                            ref.watch(spacesStreamProvider).value ?? [];
                        if (spaces.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            const Text('同步至空間 (Linked Mirroring)：'),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: spaces.map((sp) {
                                final isSelected =
                                    selectedSpaceIds.contains(sp.id);
                                return FilterChip(
                                  label: Text('${sp.icon ?? '📅'} ${sp.name}'),
                                  selected: isSelected,
                                  selectedColor:
                                      sp.colorValue.withValues(alpha: 0.25),
                                  onSelected: (val) {
                                    setDialogState(() {
                                      if (val) {
                                        selectedSpaceIds.add(sp.id);
                                      } else {
                                        selectedSpaceIds.remove(sp.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
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
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final startTime = DateTime(baseDate.year, baseDate.month,
                        baseDate.day, startHour, 0);
                    final endTime = startTime.add(Duration(minutes: duration));

                    final newEvent = CalendarEvent(
                      id: UuidUtils.generate(),
                      userId: 'guest',
                      title: title,
                      startTime: startTime,
                      endTime: endTime,
                      isAnchored: isAnchored,
                      estimatedMinutes: duration,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    final db = ref.read(appDatabaseProvider);
                    final undoManager = ref.read(undoStackManagerProvider);

                    final cmd = CreateEventCommand(
                      id: UuidUtils.generate(),
                      description: '新增「$title」',
                      timestamp: DateTime.now(),
                      eventCompanion: newEvent.toCompanion(),
                      spaceIds: selectedSpaceIds.toList(),
                      database: db,
                      userId: 'guest',
                    );

                    await undoManager.execute(cmd);
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

  void _scheduleFromOptimalSlot(
      BuildContext context, WidgetRef ref, OptimalMeetingSlot slot) async {
    final title = '排定會議 (${slot.durationMinutes}m)';
    final db = ref.read(appDatabaseProvider);
    final undoManager = ref.read(undoStackManagerProvider);
    final defaultSpace = await db.spaceDao.getDefaultSpace();
    final spaceId = defaultSpace?.id ?? 'default_space';

    final newEvent = CalendarEvent(
      id: UuidUtils.generate(),
      userId: 'guest',
      title: title,
      startTime: slot.startTime,
      endTime: slot.endTime,
      isAnchored: false,
      estimatedMinutes: slot.durationMinutes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final cmd = CreateEventCommand(
      id: UuidUtils.generate(),
      description: '排定「$title」',
      timestamp: DateTime.now(),
      eventCompanion: newEvent.toCompanion(),
      spaceIds: [spaceId],
      database: db,
      userId: 'guest',
    );
    await undoManager.execute(cmd);
  }
}
