import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'database_connection_factory.dart';

class InMemoryDatabaseConnectionFactory implements DatabaseConnectionFactory {
  final Map<String, NativeDatabase> _activeDatabases = {};

  @override
  DatabaseConnection createConnection(String dbName) {
    final db = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
    _activeDatabases[dbName] = db;
    return DatabaseConnection(db, closeStreamsSynchronously: true);
  }

  @override
  Future<bool> databaseExists(String dbName) async {
    return _activeDatabases.containsKey(dbName);
  }

  @override
  Future<void> deleteDatabase(String dbName) async {
    final db = _activeDatabases.remove(dbName);
    if (db != null) {
      await db.close();
    }
  }

  void clearAll() {
    _activeDatabases.clear();
  }
}
