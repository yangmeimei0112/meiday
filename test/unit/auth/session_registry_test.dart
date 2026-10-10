import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/features/auth/presentation/providers/auth_providers.dart';

void main() {
  group('Feature #12: Multi-Device Session Registry Tests', () {
    late ProviderContainer container;
    late InMemoryDatabaseConnectionFactory inMemoryDbFactory;
    late InMemorySecureStorageService inMemoryStorage;

    setUp(() {
      inMemoryDbFactory = InMemoryDatabaseConnectionFactory();
      inMemoryStorage = InMemorySecureStorageService();
      container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('registerCurrentDevice correctly writes current terminal to user_devices', () async {
      const userId = 'user-device-test-1';
      container.read(currentAuthForDbProvider.notifier).state =
          const AuthenticatedDbAuthState(userId);

      final sessionRegistry = container.read(sessionRegistryRepositoryProvider);
      final registered = await sessionRegistry.registerCurrentDevice(userId: userId);

      expect(registered.id, isNotEmpty);
      expect(registered.userId, equals(userId));
      expect(registered.isCurrent, isTrue);
      expect(registered.deviceName, isNotEmpty);

      final activeDevices = await sessionRegistry.watchActiveDevices(userId: userId).first;
      expect(activeDevices.length, equals(1));
      expect(activeDevices.first.id, equals(registered.id));
      expect(activeDevices.first.isCurrent, isTrue);
    });

    test('kickDevice removes target device and preserves others', () async {
      const userId = 'user-device-test-2';
      container.read(currentAuthForDbProvider.notifier).state =
          const AuthenticatedDbAuthState(userId);

      final sessionRegistry = container.read(sessionRegistryRepositoryProvider);
      final currentDevice = await sessionRegistry.registerCurrentDevice(userId: userId);

      // Simulate a secondary remote device in the DB
      final db = container.read(appDatabaseProvider);
      final now = DateTime.now();
      await db.userDeviceDao.upsertDevice(
        UserDevicesCompanion.insert(
          id: 'remote-phone-id',
          userId: userId,
          deviceName: 'Pixel 8 (Android)',
          platform: 'android',
          deviceToken: 'token_remote_android',
          lastActiveAt: now,
          isCurrent: const Value(false),
          createdAt: now,
        ),
      );

      final devicesBefore = await sessionRegistry.watchActiveDevices(userId: userId).first;
      expect(devicesBefore.length, equals(2));

      // Kick the remote phone
      await sessionRegistry.kickDevice(deviceId: 'remote-phone-id', userId: userId);

      final devicesAfter = await sessionRegistry.watchActiveDevices(userId: userId).first;
      expect(devicesAfter.length, equals(1));
      expect(devicesAfter.first.id, equals(currentDevice.id));
    });

    test('kickAllOtherDevices purges all non-current sessions in single operation', () async {
      const userId = 'user-device-test-3';
      container.read(currentAuthForDbProvider.notifier).state =
          const AuthenticatedDbAuthState(userId);

      final sessionRegistry = container.read(sessionRegistryRepositoryProvider);
      final currentDevice = await sessionRegistry.registerCurrentDevice(userId: userId);

      final db = container.read(appDatabaseProvider);
      final now = DateTime.now();
      for (int i = 1; i <= 3; i++) {
        await db.userDeviceDao.upsertDevice(
          UserDevicesCompanion.insert(
            id: 'remote-device-$i',
            userId: userId,
            deviceName: 'Remote Device $i',
            platform: 'windows',
            deviceToken: 'token_$i',
            lastActiveAt: now,
            isCurrent: const Value(false),
            createdAt: now,
          ),
        );
      }

      final devicesBefore = await sessionRegistry.watchActiveDevices(userId: userId).first;
      expect(devicesBefore.length, equals(4)); // 1 current + 3 remotes

      // Kick all other devices
      await sessionRegistry.kickAllOtherDevices(
        currentDeviceId: currentDevice.id,
        userId: userId,
      );

      final devicesAfter = await sessionRegistry.watchActiveDevices(userId: userId).first;
      expect(devicesAfter.length, equals(1));
      expect(devicesAfter.first.id, equals(currentDevice.id));
    });
  });
}
