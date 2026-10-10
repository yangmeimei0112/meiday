import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';

void main() {
  group('SecureStorageService (InMemorySecureStorageService) tests', () {
    late InMemorySecureStorageService storage;

    setUp(() {
      storage = InMemorySecureStorageService();
    });

    test('write and read value', () async {
      await storage.write(key: 'jwt_token', value: 'secret_token_123');
      final val = await storage.read(key: 'jwt_token');
      expect(val, equals('secret_token_123'));
    });

    test('read non-existent key returns null', () async {
      final val = await storage.read(key: 'non_existent');
      expect(val, isNull);
    });

    test('containsKey correctly reports presence and absence', () async {
      expect(await storage.containsKey(key: 'key1'), isFalse);
      await storage.write(key: 'key1', value: 'val1');
      expect(await storage.containsKey(key: 'key1'), isTrue);
    });

    test('overwriting key updates value', () async {
      await storage.write(key: 'k', value: 'v1');
      await storage.write(key: 'k', value: 'v2');
      expect(await storage.read(key: 'k'), equals('v2'));
    });

    test('delete removes key', () async {
      await storage.write(key: 'k', value: 'v');
      await storage.delete(key: 'k');
      expect(await storage.read(key: 'k'), isNull);
    });

    test('readAll returns full map and is unmodifiable', () async {
      await storage.write(key: 'k1', value: 'v1');
      await storage.write(key: 'k2', value: 'v2');
      final all = await storage.readAll();
      expect(all, equals({'k1': 'v1', 'k2': 'v2'}));
      expect(() => all['k3'] = 'v3', throwsUnsupportedError);
    });

    test('deleteAll clears all keys', () async {
      await storage.write(key: 'k1', value: 'v1');
      await storage.write(key: 'k2', value: 'v2');
      await storage.deleteAll();
      expect(await storage.readAll(), isEmpty);
      expect(storage.entryCount, equals(0));
    });

    test('two instances are isolated', () async {
      final s2 = InMemorySecureStorageService();
      await storage.write(key: 'k', value: 'v');
      expect(await s2.read(key: 'k'), isNull);
    });
  });
}
