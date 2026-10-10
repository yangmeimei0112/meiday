import 'database_connection_factory.dart';
import 'native_database_connection_factory.dart'
    if (dart.library.js_interop) 'web_database_connection_factory.dart' as impl;

/// Creates the platform-appropriate database connection factory.
/// Native: NativeDatabaseConnectionFactory (Drift SQLite with WAL mode)
/// Web: WebDatabaseConnectionFactory (Drift Web IndexedDB)
DatabaseConnectionFactory createDefaultConnectionFactory() {
  return impl.createPlatformConnectionFactory();
}
