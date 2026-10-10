import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_database.dart';
import '../app_database_provider.dart';

abstract class DatabaseLifecycleCoordinator {
  /// Safely switches database session to [newAuthState].
  /// Explicitly flushes and closes active SQLite handle, resets memory state,
  /// and establishes target database connection.
  Future<AppDatabase> switchSession(AuthStateForDb newAuthState);

  /// Safe logout routine: severs user database handle and returns cleanly to guest mode.
  Future<AppDatabase> severAndSwitchToGuest();

  /// Gets the currently active database instance.
  AppDatabase get activeDatabase;
}

class DatabaseLifecycleCoordinatorImpl implements DatabaseLifecycleCoordinator {
  final Ref _ref;
  Future<void> _transitionQueue = Future.value();

  DatabaseLifecycleCoordinatorImpl(this._ref);

  @override
  AppDatabase get activeDatabase => _ref.read(appDatabaseProvider);

  @override
  Future<AppDatabase> switchSession(AuthStateForDb newAuthState) async {
    final completer = Completer<AppDatabase>();

    // Serialize transitions to prevent race conditions during rapid switching
    _transitionQueue = _transitionQueue.then((_) async {
      try {
        final currentAuth = _ref.read(currentAuthForDbProvider);
        if (currentAuth.userId == newAuthState.userId) {
          completer.complete(_ref.read(appDatabaseProvider));
          return;
        }

        // 1. Obtain current database handle
        final currentDb = _ref.read(appDatabaseProvider);

        // 2. Explicitly close SQLite connection and background isolates
        await currentDb.close();

        // 3. Update auth state provider (triggers Riverpod rebuild)
        _ref.read(currentAuthForDbProvider.notifier).state = newAuthState;

        // 4. Read new database instance
        final newDb = _ref.read(appDatabaseProvider);
        completer.complete(newDb);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  @override
  Future<AppDatabase> severAndSwitchToGuest() {
    return switchSession(const GuestDbAuthState());
  }
}

/// Riverpod provider for DatabaseLifecycleCoordinator
final databaseLifecycleCoordinatorProvider = Provider<DatabaseLifecycleCoordinator>((ref) {
  return DatabaseLifecycleCoordinatorImpl(ref);
});
