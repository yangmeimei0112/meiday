import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';
import 'ocr_service.dart';
import 'notification_service.dart';
import 'tray_service.dart';
import 'audio_service.dart';
import 'widget_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return FlutterSecureStorageService();
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  return MockOcrService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return MockNotificationService();
});

final trayServiceProvider = Provider<TrayService>((ref) {
  return MockTrayService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return MockAudioService();
});

final widgetSyncServiceProvider = Provider<WidgetSyncService>((ref) {
  return MockWidgetSyncService();
});
