import 'dart:typed_data';
import 'package:meta/meta.dart';
import '../../../../core/platform/ocr_service.dart';

@immutable
class OcrCaptureDraft {
  final String rawText;
  final String cleanTitle;
  final String? location;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isAllDay;
  final String? recurrenceRule;
  final double confidence;
  final OcrEngineSource engineSource;
  final Uint8List? imageBytes;
  final List<OcrLine> lines;

  const OcrCaptureDraft({
    required this.rawText,
    required this.cleanTitle,
    this.location,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.recurrenceRule,
    this.confidence = 1.0,
    this.engineSource = OcrEngineSource.mock,
    this.imageBytes,
    this.lines = const [],
  });

  OcrCaptureDraft copyWith({
    String? rawText,
    String? cleanTitle,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? recurrenceRule,
    double? confidence,
    OcrEngineSource? engineSource,
    Uint8List? imageBytes,
    List<OcrLine>? lines,
  }) {
    return OcrCaptureDraft(
      rawText: rawText ?? this.rawText,
      cleanTitle: cleanTitle ?? this.cleanTitle,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      confidence: confidence ?? this.confidence,
      engineSource: engineSource ?? this.engineSource,
      imageBytes: imageBytes ?? this.imageBytes,
      lines: lines ?? this.lines,
    );
  }
}
