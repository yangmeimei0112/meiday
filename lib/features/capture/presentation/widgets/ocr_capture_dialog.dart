import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/platform/ocr_service.dart';
import '../../../../core/utils/uuid_utils.dart';
import '../../../calendar/application/commands/create_event_command.dart';
import '../../../calendar/application/undo/undo_stack_providers.dart';
import '../../domain/entities/ocr_capture_draft.dart';

class OcrCaptureDialog extends ConsumerStatefulWidget {
  final OcrCaptureDraft draft;
  final String userId;

  const OcrCaptureDialog({
    super.key,
    required this.draft,
    this.userId = 'guest',
  });

  static Future<void> show(
    BuildContext context, {
    required OcrCaptureDraft draft,
    String userId = 'guest',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: OcrCaptureDialog(draft: draft, userId: userId),
      ),
    );
  }

  @override
  ConsumerState<OcrCaptureDialog> createState() => _OcrCaptureDialogState();
}

class _OcrCaptureDialogState extends ConsumerState<OcrCaptureDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _rawTextController;
  late bool _isAnchored;
  late DateTime? _startTime;
  late DateTime? _endTime;
  late bool _isAllDay;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.cleanTitle);
    _locationController = TextEditingController(text: widget.draft.location ?? '');
    _rawTextController = TextEditingController(text: widget.draft.rawText);
    _isAnchored = false;
    _startTime = widget.draft.startTime;
    _endTime = widget.draft.endTime;
    _isAllDay = widget.draft.isAllDay;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _rawTextController.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final eventId = UuidUtils.generate();

    final companion = CalendarEventsCompanion(
      id: drift.Value(eventId),
      userId: drift.Value(widget.userId),
      title: drift.Value(title),
      location: drift.Value(_locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null),
      description: drift.Value('由 OCR 辨識匯入：\n${_rawTextController.text.trim()}'),
      startTime: drift.Value(_startTime),
      endTime: drift.Value(_endTime),
      isAllDay: drift.Value(_isAllDay),
      isAnchored: drift.Value(_isAnchored),
      recurrenceRule: drift.Value(widget.draft.recurrenceRule),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    final command = CreateEventCommand(
      id: UuidUtils.generate(),
      description: 'OCR 匯入日程：$title',
      timestamp: now,
      eventCompanion: companion,
      database: db,
      userId: widget.userId,
    );

    await ref.read(undoStackManagerProvider).execute(command);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已由 OCR 建立日程：$title'),
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

    final Color badgeColor;
    final String badgeLabel;
    if (widget.draft.confidence >= 0.80) {
      badgeColor = Colors.green;
      badgeLabel = '高可信度 ${(widget.draft.confidence * 100).toInt()}%';
    } else if (widget.draft.confidence >= 0.60) {
      badgeColor = Colors.orange;
      badgeLabel = '中等可信度 ${(widget.draft.confidence * 100).toInt()}%';
    } else {
      badgeColor = Colors.red;
      badgeLabel = '低可信度 ${(widget.draft.confidence * 100).toInt()}%';
    }

    final String engineName = switch (widget.draft.engineSource) {
      OcrEngineSource.winrt => 'Windows WinRT (離線 0 成本)',
      OcrEngineSource.mlkit => 'Google ML Kit (離線)',
      OcrEngineSource.cloudByok => 'BYOK Cloud AI',
      OcrEngineSource.mock => 'Mock OCR Engine',
    };

    return Container(
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Engine & Confidence Badges
            Row(
              children: [
                const Icon(Icons.document_scanner, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'OCR 行程智慧識別',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor, width: 1),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '識別引擎：$engineName',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Title Field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '行程標題',
                prefixIcon: Icon(Icons.title, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Location Field
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '會議地點 / 線上會議室 (選填)',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Time & Date Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _isAllDay && _startTime != null
                        ? '${DateFormat('yyyy/MM/dd').format(_startTime!)} (全天)'
                        : (_startTime != null
                            ? '${DateFormat('yyyy/MM/dd HH:mm').format(_startTime!)}${_endTime != null ? ' - ${DateFormat('HH:mm').format(_endTime!)}' : ''}'
                            : '未辨識到明確時間 (將存為靈感備忘)'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Track Classification
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text('排程軌道：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ChoiceChip(
                  label: const Text('固定錨定 (Track 1)'),
                  selected: _isAnchored,
                  onSelected: (val) => setState(() => _isAnchored = true),
                ),
                ChoiceChip(
                  label: const Text('彈性區塊 (Track 2)'),
                  selected: !_isAnchored,
                  onSelected: (val) => setState(() => _isAnchored = false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Raw OCR Recognized Text Accordion
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('檢視原始 OCR 辨識文字', style: TextStyle(fontSize: 12)),
                children: [
                  TextField(
                    controller: _rawTextController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '原始辨識文字',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('捨棄'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('確認建立日程'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _onConfirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
