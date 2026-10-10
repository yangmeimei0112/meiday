import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('FlutterSecureStorageService Production Tests', () {
    late FlutterSecureStorageService service;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      service = FlutterSecureStorageService();
      await service.deleteAll();
    });

    test('write, read, containsKey lifecycle works seamlessly', () async {
      expect(await service.containsKey(key: 'auth_token'), isFalse);
      expect(await service.read(key: 'auth_token'), isNull);

      await service.write(key: 'auth_token', value: 'jwt_mock_token_123');

      expect(await service.containsKey(key: 'auth_token'), isTrue);
      expect(await service.read(key: 'auth_token'), equals('jwt_mock_token_123'));
    });

    test('delete removes specified key', () async {
      await service.write(key: 'refresh_token', value: 'refresh_mock_456');
      expect(await service.containsKey(key: 'refresh_token'), isTrue);

      await service.delete(key: 'refresh_token');
      expect(await service.containsKey(key: 'refresh_token'), isFalse);
      expect(await service.read(key: 'refresh_token'), isNull);
    });

    test('readAll and deleteAll manage multiple secure entries', () async {
      await service.write(key: 'k1', value: 'v1');
      await service.write(key: 'k2', value: 'v2');

      final entries = await service.readAll();
      expect(entries['k1'], equals('v1'));
      expect(entries['k2'], equals('v2'));

      await service.deleteAll();
      final cleared = await service.readAll();
      expect(cleared.isEmpty, isTrue);
    });

    test('Custom underlying storage instance injection works', () async {
      FlutterSecureStorage.setMockInitialValues({'injected_key': 'injected_val'});
      const customStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        wOptions: WindowsOptions(),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      final customService = FlutterSecureStorageService(storage: customStorage);

      expect(await customService.read(key: 'injected_key'), equals('injected_val'));
    });
  });

  group('InMemorySecureStorageService Headless Tests', () {
    late InMemorySecureStorageService inMemory;

    setUp(() {
      inMemory = InMemorySecureStorageService();
    });

    test('in-memory key-value operations function correctly', () async {
      await inMemory.write(key: 'mem_key', value: 'mem_val');
      expect(await inMemory.containsKey(key: 'mem_key'), isTrue);
      expect(await inMemory.read(key: 'mem_key'), equals('mem_val'));
      expect(inMemory.entryCount, equals(1));

      final all = await inMemory.readAll();
      expect(all['mem_key'], equals('mem_val'));

      await inMemory.delete(key: 'mem_key');
      expect(await inMemory.containsKey(key: 'mem_key'), isFalse);
      expect(inMemory.entryCount, equals(0));
    });

    test('deleteAll and reset purge all memory entries', () async {
      await inMemory.write(key: 'a', value: '1');
      await inMemory.write(key: 'b', value: '2');
      expect(inMemory.entryCount, equals(2));

      await inMemory.deleteAll();
      expect(inMemory.entryCount, equals(0));

      await inMemory.write(key: 'c', value: '3');
      inMemory.reset();
      expect(inMemory.entryCount, equals(0));
    });
  });

  group('Riverpod SecureStorageServiceProvider Integration', () {
    test('Default container supplies FlutterSecureStorageService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(secureStorageServiceProvider);
      expect(service, isA<FlutterSecureStorageService>());
    });

    test('ProviderContainer can be overridden with InMemorySecureStorageService', () {
      final memoryMock = InMemorySecureStorageService();
      final container = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(memoryMock),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(secureStorageServiceProvider);
      expect(service, isA<InMemorySecureStorageService>());
      expect(service, equals(memoryMock));
    });
  });
}
