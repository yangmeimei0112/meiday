import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'database_connection_factory.dart';

class NativeDatabaseConnectionFactory implements DatabaseConnectionFactory {
  final Future<Directory> Function()? appDirectoryResolver;

  NativeDatabaseConnectionFactory({this.appDirectoryResolver});

  Future<File> getDatabaseFile(String dbName) async {
    final baseDir = appDirectoryResolver != null
        ? await appDirectoryResolver!()
        : await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(baseDir.path, 'ChronoHub', 'databases'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return File(p.join(dbDir.path, dbName));
  }

  @override
  DatabaseConnection createConnection(String dbName) {
    return DatabaseConnection.delayed(Future.sync(() async {
      final file = await getDatabaseFile(dbName);
      return NativeDatabase.createBackgroundConnection(
        file,
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA synchronous = NORMAL;');
        },
      );
    }));
  }

  @override
  Future<bool> databaseExists(String dbName) async {
    final file = await getDatabaseFile(dbName);
    return file.exists();
  }

  @override
  Future<void> deleteDatabase(String dbName) async {
    final file = await getDatabaseFile(dbName);
    if (await file.exists()) {
      await file.delete();
    }
    final walFile = File('${file.path}-wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }
    final shmFile = File('${file.path}-shm');
    if (await shmFile.exists()) {
      await shmFile.delete();
    }
  }
}

DatabaseConnectionFactory createPlatformConnectionFactory() => NativeDatabaseConnectionFactory();

