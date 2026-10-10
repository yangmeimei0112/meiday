// ignore_for_file: deprecated_member_use, experimental_member_use
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'database_connection_factory.dart';

class WebDatabaseConnectionFactory implements DatabaseConnectionFactory {
  @override
  DatabaseConnection createConnection(String dbName) {
    return DatabaseConnection(
      WebDatabase.withStorage(DriftWebStorage.indexedDb(dbName)),
    );
  }

  @override
  Future<bool> databaseExists(String dbName) async {
    return true;
  }

  @override
  Future<void> deleteDatabase(String dbName) async {
    // IndexedDB databases on web
  }
}

DatabaseConnectionFactory createPlatformConnectionFactory() => WebDatabaseConnectionFactory();
