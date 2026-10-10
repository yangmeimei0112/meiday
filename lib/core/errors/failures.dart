import 'package:meta/meta.dart';

@immutable
sealed class Failure {
  final String message;
  final String? code;
  final Object? cause;

  const Failure(this.message, {this.code, this.cause});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => Object.hash(runtimeType, message, code);

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Local SQLite / Drift storage failure
final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code, super.cause});
}

/// Authentication and session management failure
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code, super.cause});
}

/// Scheduling conflict (e.g. rigid anchor collision or capacity overflow)
final class ScheduleConflictFailure extends Failure {
  final String? collidingEventId;
  const ScheduleConflictFailure(super.message, {this.collidingEventId, super.code, super.cause});
}

/// Natural Language Processing parse failure
final class NlpParseFailure extends Failure {
  const NlpParseFailure(super.message, {super.code, super.cause});
}

/// Optical Character Recognition text extraction failure
final class OcrFailure extends Failure {
  const OcrFailure(super.message, {super.code, super.cause});
}

/// Cloud sync, Outbox queue, or Supabase network failure
final class SyncFailure extends Failure {
  final int? statusCode;
  const SyncFailure(super.message, {this.statusCode, super.code, super.cause});
}

/// Secure storage failure (DPAPI, Keychain, Keystore)
final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code, super.cause});
}

/// Platform service failure (Tray, Hotkey, Audio, Notifications)
final class PlatformFailure extends Failure {
  const PlatformFailure(super.message, {super.code, super.cause});
}
