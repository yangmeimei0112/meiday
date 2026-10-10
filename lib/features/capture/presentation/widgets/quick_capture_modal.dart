import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../../calendar/application/commands/create_event_command.dart';
import '../../../calendar/application/undo/undo_stack_providers.dart';
import '../../../social/presentation/providers/space_providers.dart';
import '../providers/capture_providers.dart';
import 'nlp_preview_chips.dart';

class QuickCaptureModal extends ConsumerStatefulWidget {
  final String userId;

  const QuickCaptureModal({super.key, this.userId = 'guest'});

  static Future<void> show(BuildContext context, {String userId = 'guest'}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: QuickCaptureModal(userId: userId),
      ),
    );
  }

  @override
  ConsumerState<QuickCaptureModal> createState() => _QuickCaptureModalState();
}

class _QuickCaptureModalState extends ConsumerState<QuickCaptureModal> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isAnchored = false;
  final Set<String> _selectedSpaceIds = {};

  late final FocusNode _keyboardFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _keyboardFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onSubmitted({bool keepOpen = false}) async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) return;

    final parser = ref.read(nlpParserProvider);
    final parsed = parser.parse(rawText);

    final db = ref.read(appDatabaseProvider);
    final eventId = UuidUtils.generate();
    final now = DateTime.now();

    // Map tags to spaces if spaces exist
    final spaces = ref.read(spacesStreamProvider).value ?? [];
    for (final tag in parsed.tags) {
      for (final sp in spaces) {
        if (sp.name.toLowerCase() == tag.toLowerCase()) {
          _selectedSpaceIds.add(sp.id);
          break;
        }
      }
    }

    final companion = CalendarEventsCompanion(
      id: drift.Value(eventId),
      userId: drift.Value(widget.userId),
      title: drift.Value(parsed.cleanTitle),
      description: drift.Value(rawText != parsed.cleanTitle ? rawText : null),
      startTime: drift.Value(parsed.startTime),
      endTime: drift.Value(parsed.endTime),
      isAllDay: drift.Value(parsed.isAllDay),
      isAnchored: drift.Value(_isAnchored),
      priority: drift.Value(parsed.priority),
      estimatedMinutes: drift.Value(parsed.durationMinutes),
      recurrenceRule: drift.Value(parsed.recurrenceRule),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    final command = CreateEventCommand(
      id: UuidUtils.generate(),
      description: 'NLP 速記建立：${parsed.cleanTitle}',
      timestamp: now,
      eventCompanion: companion,
      spaceIds: _selectedSpaceIds.toList(),
      database: db,
      userId: widget.userId,
    );

    await ref.read(undoStackManagerProvider).execute(command);

    if (mounted) {
      if (!keepOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      } else {
        _controller.clear();
        _selectedSpaceIds.clear();
        ref.read(quickCaptureInputProvider.notifier).state = '';
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已建立日程：${parsed.cleanTitle}'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '復原',
            onPressed: () => ref.read(undoStackManagerProvider).undo(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parser = ref.watch(nlpParserProvider);
    final inputText = ref.watch(quickCaptureInputProvider);
    final parsedResult = parser.parse(inputText);

    return FocusScope(
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context, rootNavigator: true).pop();
            } else if (event.logicalKey == LogicalKeyboardKey.keyA &&
                HardwareKeyboard.instance.isAltPressed) {
              setState(() => _isAnchored = !_isAnchored);
            }
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title & close
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'NLP 智慧速記 (Quick Capture)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main input field
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: '例：明天下午3點開會 #工作 !1 for 1h、每週五健身...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  ref.read(quickCaptureInputProvider.notifier).state = val;
                },
                onSubmitted: (_) {
                  final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                  _onSubmitted(keepOpen: isShiftPressed);
                },
              ),
              const SizedBox(height: 12),

              // Real-time Preview Chips
              if (_controller.text.trim().isNotEmpty) ...[
                Text(
                  '語意解析結果：',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                NlpPreviewChips(
                  result: parsedResult,
                  isAnchored: _isAnchored,
                  onToggleAnchored: (val) => setState(() => _isAnchored = val),
                ),
                const SizedBox(height: 14),
              ],

              // Footer actions: helper shortcut hint & submit button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '按 Enter 提交 • Shift+Enter 連續建立 • Esc 關閉',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('新增日程'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _controller.text.trim().isNotEmpty ? () => _onSubmitted() : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
