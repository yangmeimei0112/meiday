import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/connection/native_database_connection_factory.dart';

void main() {
  group('DatabaseConnectionFactory tests', () {
    test('InMemoryDatabaseConnectionFactory creates isolated connections', () async {
      final factory = InMemoryDatabaseConnectionFactory();

      final conn1 = factory.createConnection('test1.db');
      expect(conn1, isNotNull);
      expect(await factory.databaseExists('test1.db'), isTrue);
      expect(await factory.databaseExists('test2.db'), isFalse);

      await factory.deleteDatabase('test1.db');
      expect(await factory.databaseExists('test1.db'), isFalse);
    });

    test('NativeDatabaseConnectionFactory resolves directory path correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('chronohub_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final factory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );

      final dbFile = await factory.getDatabaseFile('guest.db');
      expect(dbFile.path, contains('ChronoHub'));
      expect(dbFile.path, contains('databases'));
      expect(dbFile.path, endsWith('guest.db'));
    });
  });
}
