import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';

void main() {
  group('Multi-Tenant Database Physical Isolation tests', () {
    test('guest.db and user_xxx.db are completely isolated', () async {
      final factory = InMemoryDatabaseConnectionFactory();

      final guestDbName = resolveDatabaseName(null);
      expect(guestDbName, equals('guest.db'));

      final userDbName = resolveDatabaseName('user-test-uid-456');
      expect(userDbName, startsWith('user_'));
      expect(userDbName, isNot(equals('guest.db')));

      // Connect to guest DB
      final guestDb = AppDatabase(factory.createConnection(guestDbName));
      final now = DateTime.now();
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'guest-space-1',
          userId: 'guest',
          name: '訪客專屬空間',
          type: 'personal',
          color: 0xFF6366F1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final guestSpaces = await guestDb.spaceDao.watchAllSpaces().first;
      expect(guestSpaces.length, equals(1));
      expect(guestSpaces.first.id, equals('guest-space-1'));

      // Connect to user DB
      final userDb = AppDatabase(factory.createConnection(userDbName));
      final userSpaces = await userDb.spaceDao.watchAllSpaces().first;
      // Physical isolation: user DB MUST be completely empty initially!
      expect(userSpaces.isEmpty, isTrue);

      // Write to user DB
      await userDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'user-space-1',
          userId: 'user-test-uid-456',
          name: '會員專屬空間',
          type: 'personal',
          color: 0xFF06B6D4,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final userSpacesAfter = await userDb.spaceDao.watchAllSpaces().first;
      expect(userSpacesAfter.length, equals(1));
      expect(userSpacesAfter.first.id, equals('user-space-1'));

      // Guest DB should still have ONLY guest space
      final guestSpacesAfter = await guestDb.spaceDao.watchAllSpaces().first;
      expect(guestSpacesAfter.length, equals(1));
      expect(guestSpacesAfter.first.id, equals('guest-space-1'));

      await guestDb.close();
      await userDb.close();
    });
  });
}
