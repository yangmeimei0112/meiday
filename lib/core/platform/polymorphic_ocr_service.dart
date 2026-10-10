import 'dart:typed_data';
import 'byok_cloud_ocr_service.dart';
import 'ocr_service.dart';

/// Polymorphic OCR Orchestrator:
/// Routes to platform native offline engine (WinRT on Windows, ML Kit on mobile)
/// and seamlessly fails over to BYOK Cloud when offline confidence is low and user opted in.
class PolymorphicOcrService implements OcrService {
  final OcrService primaryOfflineEngine;
  final ByokCloudOcrService? cloudFallbackEngine;

  PolymorphicOcrService({
    required this.primaryOfflineEngine,
    this.cloudFallbackEngine,
  });

  @override
  Future<bool> isAvailable() async {
    final offlineReady = await primaryOfflineEngine.isAvailable();
    if (offlineReady) return true;
    return await cloudFallbackEngine?.isAvailable() ?? false;
  }

  @override
  Future<OcrResult> extractText(Uint8List imageBytes, {String? languageHint}) async {
    OcrResult? offlineResult;
    try {
      offlineResult = await primaryOfflineEngine.extractText(
        imageBytes,
        languageHint: languageHint,
      );
    } catch (_) {
      // Offline failure, try cloud fallback if configured
      if (cloudFallbackEngine != null && await cloudFallbackEngine!.isAvailable()) {
        return await cloudFallbackEngine!.extractText(
          imageBytes,
          languageHint: languageHint,
        );
      }
      rethrow;
    }

    // Check if cloud fallback criteria are met:
    // 1. Cloud fallback is configured and autoFallback is enabled
    // 2. Offline result confidence is below threshold or empty
    final byok = cloudFallbackEngine;
    if (byok != null &&
        byok.settings.byokEnabled &&
        byok.settings.autoFallback &&
        (offlineResult.confidence < byok.settings.confidenceThreshold || offlineResult.isEmpty)) {
      try {
        final cloudResult = await byok.extractText(
          imageBytes,
          languageHint: languageHint,
        );
        return cloudResult;
      } catch (_) {
        // Fallback failed, return offline result
        return offlineResult;
      }
    }

    return offlineResult;
  }

  /// Explicit user request for cloud AI vision enhancement
  Future<OcrResult> extractTextWithCloudOnly(Uint8List imageBytes, {String? languageHint}) async {
    if (cloudFallbackEngine == null) {
      throw Exception('BYOK Cloud OCR service not configured');
    }
    return cloudFallbackEngine!.extractText(imageBytes, languageHint: languageHint);
  }

  @override
  Future<OcrResult> extractTextFromPath(String imagePath, {String? languageHint}) async {
    return primaryOfflineEngine.extractTextFromPath(imagePath, languageHint: languageHint);
  }
}
