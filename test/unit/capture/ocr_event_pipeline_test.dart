import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/ocr_service.dart';
import 'package:smart_calendar_hub/features/capture/application/bilingual_nlp_parser.dart';
import 'package:smart_calendar_hub/features/capture/application/ocr_event_pipeline.dart';

void main() {
  group('OcrEventPipeline Unit Tests', () {
    late MockOcrService mockOcr;
    const nlpParser = BilingualNlpParser();
    late OcrEventPipeline pipeline;
    final ref = DateTime(2026, 10, 15, 9, 0, 0);

    setUp(() {
      mockOcr = MockOcrService();
      pipeline = OcrEventPipeline(ocrService: mockOcr, nlpParser: nlpParser);
    });

    test('Pipes OCR text with meeting title, time and location', () async {
      mockOcr.setCannedText(
        '明天下午3點 專案進度週會\n地點：會議室 B',
        confidence: 0.96,
        source: OcrEngineSource.winrt,
      );

      final draft = await pipeline.processImage(
        Uint8List.fromList([1, 2, 3]),
        referenceTime: ref,
      );

      expect(draft.cleanTitle, equals('專案進度週會'));
      expect(draft.location, equals('會議室 B'));
      expect(draft.startTime, equals(DateTime(2026, 10, 16, 15, 0)));
      expect(draft.confidence, equals(0.96));
      expect(draft.engineSource, equals(OcrEngineSource.winrt));
      expect(draft.lines.length, equals(2));
    });

    test('Pipes English OCR text with location cue', () async {
      mockOcr.setCannedText(
        'Friday 10am to 11am Client Sync\nLocation: Google Meet',
        confidence: 0.94,
        source: OcrEngineSource.mlkit,
      );

      final draft = await pipeline.processImage(
        Uint8List.fromList([4, 5, 6]),
        referenceTime: ref,
      );

      expect(draft.cleanTitle, equals('Client Sync'));
      expect(draft.location, equals('Google Meet'));
      // Friday: Oct 15 is Thursday, so Friday is Oct 16
      expect(draft.startTime, equals(DateTime(2026, 10, 16, 10, 0)));
      expect(draft.endTime, equals(DateTime(2026, 10, 16, 11, 0)));
      expect(draft.engineSource, equals(OcrEngineSource.mlkit));
    });

    test('Handles OCR text with no explicit location', () async {
      mockOcr.setCannedText(
        '明天下午2點 線上代碼審查',
        confidence: 0.88,
      );

      final draft = await pipeline.processImage(
        Uint8List.fromList([7, 8]),
        referenceTime: ref,
      );

      expect(draft.cleanTitle, equals('線上代碼審查'));
      expect(draft.location, isNull);
      expect(draft.startTime, equals(DateTime(2026, 10, 16, 14, 0)));
    });
  });
}
