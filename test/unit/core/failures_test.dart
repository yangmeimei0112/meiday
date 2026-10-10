import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/errors/failures.dart';
import 'package:smart_calendar_hub/core/errors/exceptions.dart';

void main() {
  group('Failure hierarchy tests', () {
    test('DatabaseFailure properties and equality', () {
      const f1 = DatabaseFailure('Disk full', code: 'SQLITE_FULL');
      const f2 = DatabaseFailure('Disk full', code: 'SQLITE_FULL');
      const f3 = DatabaseFailure('Table not found');

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));
      expect(f1.message, equals('Disk full'));
      expect(f1.code, equals('SQLITE_FULL'));
      expect(f1.toString(), contains('DatabaseFailure'));
    });

    test('AuthFailure properties and equality', () {
      const f1 = AuthFailure('Invalid credentials', code: 'INVALID_GRANT');
      expect(f1.message, equals('Invalid credentials'));
      expect(f1.code, equals('INVALID_GRANT'));
    });

    test('ScheduleConflictFailure supports collidingEventId', () {
      const f = ScheduleConflictFailure(
        'Collision with anchor',
        collidingEventId: 'anchor-123',
      );
      expect(f.collidingEventId, equals('anchor-123'));
      expect(f.message, contains('Collision'));
    });

    test('SyncFailure supports statusCode', () {
      const f = SyncFailure('Network timeout', statusCode: 504);
      expect(f.statusCode, equals(504));
    });

    test('All failure types instantiate correctly', () {
      expect(const NlpParseFailure('Bad date').message, 'Bad date');
      expect(const OcrFailure('Image unreadable').message, 'Image unreadable');
      expect(const StorageFailure('Keystore locked').message, 'Keystore locked');
      expect(const PlatformFailure('Tray failed').message, 'Tray failed');
    });
  });

  group('AppException hierarchy tests', () {
    test('AppException and subclasses have proper messages', () {
      const e1 = DatabaseException('DB error', code: 'ERR_DB');
      expect(e1.message, 'DB error');
      expect(e1.code, 'ERR_DB');
      expect(e1.toString(), contains('AppException: DB error'));

      expect(const AuthException('Auth error').message, 'Auth error');
      expect(const StorageException('Storage error').message, 'Storage error');
      expect(const PlatformServiceException('Platform error').message, 'Platform error');
      expect(const SyncException('Sync error').message, 'Sync error');
    });
  });
}
