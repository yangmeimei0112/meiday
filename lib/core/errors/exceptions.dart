class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.cause});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.cause});
}

class PlatformServiceException extends AppException {
  const PlatformServiceException(super.message, {super.code, super.cause});
}

class SyncException extends AppException {
  const SyncException(super.message, {super.code, super.cause});
}
