import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/errors/failures.dart';
import 'package:smart_calendar_hub/core/platform/byok_cloud_ocr_service.dart';
import 'package:smart_calendar_hub/core/platform/mlkit_ocr_service.dart';
import 'package:smart_calendar_hub/core/platform/ocr_service.dart';
import 'package:smart_calendar_hub/core/platform/polymorphic_ocr_service.dart';
import 'package:smart_calendar_hub/core/platform/winrt_ocr_service.dart';

class MockByokClient implements ByokHttpClient {
  bool wasCalled = false;
  String cannedText = '2026/10/22 10:00 雲端解析會議';

  @override
  Future<Map<String, dynamic>> postJson(
    String url, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    wasCalled = true;
    return {'text': cannedText};
  }
}

class TestMlKitAdapter implements MlKitAdapter {
  bool wasCalled = false;

  @override
  Future<OcrResult> processBytes(Uint8List bytes, {String? languageHint}) async {
    wasCalled = true;
    return const OcrResult(
      text: '2026/10/18 16:00 移動端辨識結果',
      lines: [OcrLine(text: '2026/10/18 16:00 移動端辨識結果', confidence: 0.95)],
      confidence: 0.95,
      source: OcrEngineSource.mlkit,
    );
  }
}

void main() {
  group('1. Polymorphic OcrResult & OcrLine Models', () {
    test('BoundingBox serialization and properties', () {
      const box = OcrBoundingBox(left: 10, top: 20, width: 100, height: 50);
      expect(box.right, equals(110));
      expect(box.bottom, equals(70));
      final json = box.toJson();
      final copy = OcrBoundingBox.fromJson(json);
      expect(copy.left, equals(10));
      expect(copy.width, equals(100));
    });

    test('OcrLine and OcrResult rawLines getter', () {
      const line1 = OcrLine(text: '第一行文字', confidence: 0.9);
      const line2 = OcrLine(text: '第二行文字', confidence: 0.85);
      const res = OcrResult(
        text: '第一行文字\n第二行文字',
        lines: [line1, line2],
        confidence: 0.88,
        source: OcrEngineSource.winrt,
      );
      expect(res.rawLines, equals(['第一行文字', '第二行文字']));
      expect(res.source, equals(OcrEngineSource.winrt));
      expect(res.isLowConfidence, isFalse);
    });

    test('Low confidence threshold detection (< 0.60)', () {
      const lowRes = OcrResult(
        text: '模糊文字',
        lines: [OcrLine(text: '模糊文字', confidence: 0.45)],
        confidence: 0.45,
      );
      expect(lowRes.isLowConfidence, isTrue);
    });
  });

  group('2. MockOcrService Compatibility Tests', () {
    late MockOcrService ocr;

    setUp(() {
      ocr = MockOcrService();
    });

    test('isAvailable default and toggling', () async {
      expect(await ocr.isAvailable(), isTrue);
      ocr.setAvailability(false);
      expect(await ocr.isAvailable(), isFalse);
    });

    test('extractText returns default mock result when unconfigured', () async {
      final res = await ocr.extractText(Uint8List.fromList([1, 2, 3]));
      expect(res.text, contains('專案週會'));
      expect(res.lines.length, equals(2));
      expect(res.confidence, equals(0.98));
      expect(ocr.callCount, equals(1));
      expect(ocr.lastImageBytes, isNotNull);
    });

    test('setCannedText sets custom response', () async {
      ocr.setCannedText('2026/11/01 10:00 牙醫看診\n診所大安路', confidence: 0.95);
      final res = await ocr.extractTextFromPath('test.jpg');
      expect(res.text, contains('牙醫看診'));
      expect(res.lines.length, equals(2));
      expect(res.confidence, equals(0.95));
      expect(ocr.lastImagePath, equals('test.jpg'));
    });

    test('setCannedError throws on extract', () async {
      ocr.setCannedError(Exception('OCR engine crash'));
      expect(() => ocr.extractText(Uint8List(0)), throwsException);
    });
  });

  group('3. WinrtOcrService Headless Safety', () {
    test('extractText on empty bytes returns OcrResult.empty', () async {
      final winrt = WinrtOcrService();
      final res = await winrt.extractText(Uint8List(0));
      expect(res.isEmpty, isTrue);
    });

    test('extractText handles MissingPluginException gracefully by throwing OcrFailure', () async {
      final winrt = WinrtOcrService();
      expect(
        () => winrt.extractText(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<OcrFailure>()),
      );
    });
  });

  group('4. MlKitOcrService Adapter Isolation', () {
    test('MlKit delegates to adapter in test environment', () async {
      final adapter = TestMlKitAdapter();
      final mlkit = MlKitOcrService(adapter: adapter);
      expect(await mlkit.isAvailable(), isTrue);

      final res = await mlkit.extractText(Uint8List.fromList([10, 20, 30]));
      expect(adapter.wasCalled, isTrue);
      expect(res.source, equals(OcrEngineSource.mlkit));
      expect(res.text, contains('移動端辨識結果'));
    });
  });

  group('5. ByokCloudOcrService Zero-Cloud Default', () {
    test('BYOK is disabled by default and throws on extractText', () async {
      final byok = ByokCloudOcrService();
      expect(await byok.isAvailable(), isFalse);
      expect(
        () => byok.extractText(Uint8List.fromList([1, 2])),
        throwsA(isA<OcrFailure>()),
      );
    });

    test('BYOK calls client when enabled with API key', () async {
      final client = MockByokClient();
      final byok = ByokCloudOcrService(
        settings: const OcrSettings(
          byokEnabled: true,
          apiKey: 'test-api-key',
          provider: ByokProvider.openAi,
        ),
        client: client,
      );
      expect(await byok.isAvailable(), isTrue);

      final res = await byok.extractText(Uint8List.fromList([5, 6, 7]));
      expect(client.wasCalled, isTrue);
      expect(res.source, equals(OcrEngineSource.cloudByok));
      expect(res.text, contains('雲端解析會議'));
    });
  });

  group('6. PolymorphicOcrService Routing & Fallback', () {
    test('Routes to primary offline engine when confidence is high', () async {
      final mockPrimary = MockOcrService();
      mockPrimary.setCannedText('高清晰日程 14:00', confidence: 0.95);
      final client = MockByokClient();
      final byok = ByokCloudOcrService(
        settings: const OcrSettings(
          byokEnabled: true,
          apiKey: 'key',
          autoFallback: true,
          confidenceThreshold: 0.60,
        ),
        client: client,
      );

      final orchestrator = PolymorphicOcrService(
        primaryOfflineEngine: mockPrimary,
        cloudFallbackEngine: byok,
      );

      final res = await orchestrator.extractText(Uint8List.fromList([1]));
      expect(res.text, contains('高清晰日程'));
      expect(client.wasCalled, isFalse); // Zero cloud calls made!
    });

    test('Seamlessly falls back to BYOK cloud engine when offline confidence is low', () async {
      final mockPrimary = MockOcrService();
      mockPrimary.setCannedText('模糊難辨文字', confidence: 0.40); // < 0.60
      final client = MockByokClient();
      client.cannedText = '雲端辨識成功 16:30 會議';
      final byok = ByokCloudOcrService(
        settings: const OcrSettings(
          byokEnabled: true,
          apiKey: 'key',
          autoFallback: true,
          confidenceThreshold: 0.60,
        ),
        client: client,
      );

      final orchestrator = PolymorphicOcrService(
        primaryOfflineEngine: mockPrimary,
        cloudFallbackEngine: byok,
      );

      final res = await orchestrator.extractText(Uint8List.fromList([1]));
      expect(client.wasCalled, isTrue);
      expect(res.source, equals(OcrEngineSource.cloudByok));
      expect(res.text, contains('雲端辨識成功'));
    });

    test('Does NOT fall back to cloud if BYOK is disabled (preserves local-first privacy)', () async {
      final mockPrimary = MockOcrService();
      mockPrimary.setCannedText('模糊難辨文字', confidence: 0.40);
      final client = MockByokClient();
      final byok = ByokCloudOcrService(
        settings: const OcrSettings(byokEnabled: false), // Disabled!
        client: client,
      );

      final orchestrator = PolymorphicOcrService(
        primaryOfflineEngine: mockPrimary,
        cloudFallbackEngine: byok,
      );

      final res = await orchestrator.extractText(Uint8List.fromList([1]));
      expect(client.wasCalled, isFalse);
      expect(res.confidence, equals(0.40));
    });
  });
}
