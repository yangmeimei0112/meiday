import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/hash_utils.dart';
import 'app_database.dart';
import 'connection/database_connection_factory.dart';
import 'connection/default_connection_factory.dart';

/// Database connection factory provider. Overridden in tests with InMemoryDatabaseConnectionFactory.
final databaseConnectionFactoryProvider = Provider<DatabaseConnectionFactory>((ref) {
  return createDefaultConnectionFactory();
});

/// Computes the isolated physical SQLite database filename:
/// - If userId is null or empty -> 'guest.db'
/// - If userId is present -> 'user_${sha256Hex(userId)}.db' (72 chars total)
/// Delegates directly to [HashUtils.resolveDatabaseName].
String resolveDatabaseName(String? userId) => HashUtils.resolveDatabaseName(userId);

/// Abstract auth state contract for database dependency injection
abstract class AuthStateForDb {
  String? get userId;
}

class GuestDbAuthState implements AuthStateForDb {
  const GuestDbAuthState();
  @override
  String? get userId => null;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GuestDbAuthState;

  @override
  int get hashCode => 0;
}

class AuthenticatedDbAuthState implements AuthStateForDb {
  @override
  final String userId;
  const AuthenticatedDbAuthState(this.userId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthenticatedDbAuthState && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;
}

/// State provider for current user ID / auth status for database routing
final currentAuthForDbProvider = StateProvider<AuthStateForDb>((ref) {
  return const GuestDbAuthState();
});

/// Riverpod provider managing the active AppDatabase lifecycle.
/// Whenever currentAuthForDbProvider changes:
/// 1. ref.onDispose closes the previous SQLite connection, releasing file locks.
/// 2. Resolves the new physical database name (guest.db vs user_${sha256(uid)}.db).
/// 3. Creates and supplies the new AppDatabase instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final connectionFactory = ref.watch(databaseConnectionFactoryProvider);
  final authState = ref.watch(currentAuthForDbProvider);

  final dbName = resolveDatabaseName(authState.userId);
  final connection = connectionFactory.createConnection(dbName);
  final database = AppDatabase(connection);

  // Safe disposal: Sever connection immediately on logout or user switch
  ref.onDispose(() async {
    await database.close();
  });

  return database;
});
