import 'package:drift/drift.dart';

abstract class DatabaseConnectionFactory {
  /// Creates a Drift DatabaseConnection to the given SQLite database filename
  DatabaseConnection createConnection(String dbName);

  /// Checks whether the database file (or memory entry) exists
  Future<bool> databaseExists(String dbName);

  /// Permanently deletes the SQLite database file and associated WAL/SHM files
  Future<void> deleteDatabase(String dbName);
}
