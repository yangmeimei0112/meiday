import 'dart:io';
import 'package:flutter/foundation.dart';
import '../errors/failures.dart';
import 'ocr_service.dart';

abstract class MlKitAdapter {
  Future<OcrResult> processBytes(Uint8List bytes, {String? languageHint});
}

/// Mobile Google ML Kit OCR Engine Wrapper
class MlKitOcrService implements OcrService {
  final MlKitAdapter? _adapter;

  MlKitOcrService({MlKitAdapter? adapter}) : _adapter = adapter;

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (_adapter != null) return true;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<OcrResult> extractText(Uint8List imageBytes, {String? languageHint}) async {
    if (imageBytes.isEmpty) return OcrResult.empty;
    if (!await isAvailable() && _adapter == null) {
      throw const OcrFailure('Google ML Kit OCR is only available on Android and iOS');
    }
    try {
      if (_adapter != null) {
        return await _adapter.processBytes(imageBytes, languageHint: languageHint);
      }
      return OcrResult.empty;
    } catch (e) {
      throw OcrFailure('ML Kit recognition failed: $e', cause: e);
    }
  }

  @override
  Future<OcrResult> extractTextFromPath(String imagePath, {String? languageHint}) async {
    final file = File(imagePath);
    if (!await file.exists()) throw OcrFailure('Image file not found: $imagePath');
    return extractText(await file.readAsBytes(), languageHint: languageHint);
  }
}
