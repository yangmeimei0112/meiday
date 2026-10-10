import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/audio_service.dart';
import 'package:smart_calendar_hub/core/platform/notification_service.dart';
import 'package:smart_calendar_hub/core/platform/ocr_service.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/core/platform/tray_service.dart';
import 'package:smart_calendar_hub/core/platform/widget_service.dart';

void main() {
  group('Platform Providers DI tests', () {
    test('Default container instantiates mock doubles cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(secureStorageServiceProvider), isA<FlutterSecureStorageService>());
      expect(container.read(ocrServiceProvider), isA<MockOcrService>());
      expect(container.read(notificationServiceProvider), isA<MockNotificationService>());
      expect(container.read(trayServiceProvider), isA<MockTrayService>());
      expect(container.read(audioServiceProvider), isA<MockAudioService>());
      expect(container.read(widgetSyncServiceProvider), isA<MockWidgetSyncService>());
    });

    test('Provider overrides work seamlessly', () {
      final customStorage = InMemorySecureStorageService();
      final container = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(customStorage),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(secureStorageServiceProvider), equals(customStorage));
    });
  });
}
