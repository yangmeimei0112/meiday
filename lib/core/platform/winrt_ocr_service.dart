import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../errors/failures.dart';
import 'ocr_service.dart';

/// Windows 10/11 Native WinRT OCR Engine (100% offline, zero-cost)
class WinrtOcrService implements OcrService {
  final MethodChannel _channel;

  WinrtOcrService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.chronohub.ocr/winrt');

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isWindows) return false;
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<OcrResult> extractText(Uint8List imageBytes, {String? languageHint}) async {
    if (imageBytes.isEmpty) {
      return OcrResult.empty;
    }
    try {
      final dynamic raw = await _channel.invokeMethod('extractText', {
        'imageBytes': imageBytes,
        'languageHint': languageHint ?? 'zh-TW',
      });
      return _parseWinrtResult(raw);
    } on MissingPluginException catch (e) {
      throw OcrFailure('WinRT OCR plugin unavailable in headless environment: ${e.message}');
    } on PlatformException catch (e) {
      throw OcrFailure('WinRT OCR failed: ${e.message}', code: e.code, cause: e);
    } catch (e) {
      throw OcrFailure('Unexpected WinRT OCR error: $e', cause: e);
    }
  }

  @override
  Future<OcrResult> extractTextFromPath(String imagePath, {String? languageHint}) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw OcrFailure('Image file not found at: $imagePath');
    }
    final bytes = await file.readAsBytes();
    return extractText(bytes, languageHint: languageHint);
  }

  OcrResult _parseWinrtResult(dynamic raw) {
    if (raw is! Map) return OcrResult.empty;
    final map = Map<String, dynamic>.from(raw);
    final text = map['text'] as String? ?? '';
    final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.95;
    final rawLines = (map['lines'] as List<dynamic>?) ?? [];

    final lines = rawLines.map((l) {
      if (l is Map) {
        return OcrLine.fromJson(Map<String, dynamic>.from(l));
      }
      return OcrLine(text: l.toString(), confidence: confidence);
    }).toList();

    return OcrResult(
      text: text,
      lines: lines,
      confidence: confidence,
      source: OcrEngineSource.winrt,
      metadata: {'engine': 'Windows.Media.Ocr.OcrEngine'},
    );
  }
}
