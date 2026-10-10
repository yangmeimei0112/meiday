import 'dart:typed_data';
import '../../../../core/platform/ocr_service.dart';
import '../domain/entities/ocr_capture_draft.dart';
import '../domain/services/nlp_parser.dart';

class OcrEventPipeline {
  final OcrService ocrService;
  final NlpParser nlpParser;

  const OcrEventPipeline({
    required this.ocrService,
    required this.nlpParser,
  });

  Future<OcrCaptureDraft> processImage(
    Uint8List imageBytes, {
    DateTime? referenceTime,
    String? languageHint,
  }) async {
    final ocrResult = await ocrService.extractText(
      imageBytes,
      languageHint: languageHint,
    );

    // Extract secondary location cues from lines
    String? location;
    final textLinesWithoutLocation = <String>[];
    for (final line in ocrResult.lines) {
      final t = line.text.trim();
      if (t.startsWith('地點:') || t.startsWith('地點：')) {
        location ??= t.substring(3).trim();
      } else if (t.startsWith('Location:') || t.startsWith('Location :')) {
        location ??= t.substring(t.indexOf(':') + 1).trim();
      } else if (location == null && (t.contains('會議室') || t.contains('Room ') || t.contains('Google Meet'))) {
        location = t;
      } else {
        textLinesWithoutLocation.add(line.text);
      }
    }

    final textToParse = textLinesWithoutLocation.isNotEmpty
        ? textLinesWithoutLocation.join('\n')
        : ocrResult.text;

    final nlpResult = nlpParser.parse(
      textToParse,
      referenceTime: referenceTime,
    );

    return OcrCaptureDraft(
      rawText: ocrResult.text,
      cleanTitle: nlpResult.cleanTitle.isNotEmpty ? nlpResult.cleanTitle : 'OCR 識別行程',
      location: location,
      startTime: nlpResult.startTime,
      endTime: nlpResult.endTime,
      isAllDay: nlpResult.isAllDay,
      recurrenceRule: nlpResult.recurrenceRule,
      confidence: ocrResult.confidence,
      engineSource: ocrResult.source,
      imageBytes: imageBytes,
      lines: ocrResult.lines,
    );
  }
}
