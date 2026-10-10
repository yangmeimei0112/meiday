import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_session.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_user.dart';

void main() {
  group('Token Vault & AuthLocalDataSource Tests', () {
    late InMemorySecureStorageService storage;
    late AuthLocalDataSource localDataSource;

    setUp(() {
      storage = InMemorySecureStorageService();
      localDataSource = AuthLocalDataSource(storage);
    });

    test('saveSession and getSession roundtrip preserves tokens and user info', () async {
      final user = AuthUser.authenticated(
        id: 'user-vault-test-1',
        email: 'vault@chronohub.com',
        displayName: 'Vault Tester',
        createdAt: DateTime(2026, 2, 1),
      );
      final session = AuthSession(
        accessToken: 'secure_access_token_jwt_123',
        refreshToken: 'secure_refresh_token_jwt_456',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        user: user,
      );

      await localDataSource.saveSession(session);

      final retrieved = await localDataSource.getSession();
      expect(retrieved, isNotNull);
      expect(retrieved!.accessToken, equals('secure_access_token_jwt_123'));
      expect(retrieved.refreshToken, equals('secure_refresh_token_jwt_456'));
      expect(retrieved.user.id, equals('user-vault-test-1'));
      expect(retrieved.user.email, equals('vault@chronohub.com'));
      expect(retrieved.user.displayName, equals('Vault Tester'));
    });

    test('clearSession completely deletes tokens from secure vault', () async {
      final session = AuthSession(
        accessToken: 'temp_token',
        refreshToken: 'temp_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: AuthUser.guest(),
      );

      await localDataSource.saveSession(session);
      expect(await localDataSource.getSession(), isNotNull);

      await localDataSource.clearSession();
      expect(await localDataSource.getSession(), isNull);
      expect(await storage.containsKey(key: AuthLocalDataSource.keySession), isFalse);
    });

    test('getOrCreateDeviceId generates UUID and persists across repeated invocations', () async {
      final id1 = await localDataSource.getOrCreateDeviceId();
      expect(id1, isNotEmpty);
      expect(id1.length, equals(36)); // RFC4122 UUID length

      final id2 = await localDataSource.getOrCreateDeviceId();
      expect(id2, equals(id1));
    });

    test('Corrupted session data in storage safely recovers by purging and returning null', () async {
      await storage.write(
        key: AuthLocalDataSource.keySession,
        value: '{ invalid json corrupt: ',
      );

      final result = await localDataSource.getSession();
      expect(result, isNull);
      expect(await storage.containsKey(key: AuthLocalDataSource.keySession), isFalse);
    });
  });
}
