import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/utils/hash_utils.dart';

void main() {
  group('HashUtils tests', () {
    test('sha256Hex produces correct 64-character hash', () {
      // Known sha256 for empty string: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      final hash = HashUtils.sha256Hex('');
      expect(hash, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });

    test('sha256Hex produces deterministic hash for test uid', () {
      final h1 = HashUtils.sha256Hex('user-uuid-1234');
      final h2 = HashUtils.sha256Hex('user-uuid-1234');
      expect(h1, equals(h2));
      expect(h1.length, equals(64));
    });

    test('resolveDatabaseName returns guest.db for null or whitespace', () {
      expect(HashUtils.resolveDatabaseName(null), equals('guest.db'));
      expect(HashUtils.resolveDatabaseName(''), equals('guest.db'));
      expect(HashUtils.resolveDatabaseName('   '), equals('guest.db'));
    });

    test('userDbFileName returns user_<64-char-hex>.db format (total 72 chars)', () {
      final dbName = HashUtils.userDbFileName('user-uuid-1234');
      expect(dbName, startsWith('user_'));
      expect(dbName, endsWith('.db'));
      // user_ (5) + 64 hex chars + .db (3) = 72 chars
      expect(dbName.length, equals(72));
      expect(dbName, equals(HashUtils.resolveDatabaseName('user-uuid-1234')));
    });
  });
}
