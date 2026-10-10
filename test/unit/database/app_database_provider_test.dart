import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';

void main() {
  group('Riverpod appDatabaseProvider lifecycle tests', () {
    test('Swapping auth state creates new database and closes previous', () async {
      final inMemoryFactory = InMemoryDatabaseConnectionFactory();
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryFactory),
        ],
      );
      addTearDown(container.dispose);

      // Initially in Guest state
      final guestDb = container.read(appDatabaseProvider);
      expect(guestDb, isNotNull);

      // Switch to authenticated state
      container.read(currentAuthForDbProvider.notifier).state =
          const AuthenticatedDbAuthState('user-12345');

      final userDb = container.read(appDatabaseProvider);
      expect(userDb, isNotNull);
      // Different instances
      expect(identical(guestDb, userDb), isFalse);

      // Switch back to guest (simulating logout)
      container.read(currentAuthForDbProvider.notifier).state =
          const GuestDbAuthState();

      final guestDb2 = container.read(appDatabaseProvider);
      expect(identical(userDb, guestDb2), isFalse);
    });
  });
}
