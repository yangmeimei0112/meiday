import 'package:meta/meta.dart';

enum MigrationMode {
  /// Brand-new user: copy all spaces, events, and related entities.
  autoMigrate,

  /// Existing user with data: merge guest items into existing personal space.
  mergeLocal,

  /// Existing user: discard local guest draft, preserve cloud/local account data only.
  discardLocal,
}

enum MigrationScenario {
  /// guest.db is empty, no migration needed.
  noGuestData,

  /// User registered a brand-new account or target user DB has no existing calendar data.
  brandNewAccount,

  /// guest.db has data AND target account already has calendar data (requires prompt).
  existingAccountConflict,
}

@immutable
class MigrationResult {
  final bool success;
  final MigrationMode mode;
  final int spacesMigrated;
  final int eventsMigrated;
  final int linksMigrated;
  final int commentsMigrated;
  final int attachmentsMigrated;
  final int checklistsMigrated;
  final int keepItemsMigrated;
  final int pomodoroSessionsMigrated;
  final int outboxEntriesEnqueued;
  final String? errorMessage;

  const MigrationResult({
    required this.success,
    required this.mode,
    this.spacesMigrated = 0,
    this.eventsMigrated = 0,
    this.linksMigrated = 0,
    this.commentsMigrated = 0,
    this.attachmentsMigrated = 0,
    this.checklistsMigrated = 0,
    this.keepItemsMigrated = 0,
    this.pomodoroSessionsMigrated = 0,
    this.outboxEntriesEnqueued = 0,
    this.errorMessage,
  });

  factory MigrationResult.discarded() => const MigrationResult(
        success: true,
        mode: MigrationMode.discardLocal,
      );

  factory MigrationResult.failure({
    required MigrationMode mode,
    required String errorMessage,
  }) =>
      MigrationResult(
        success: false,
        mode: mode,
        errorMessage: errorMessage,
      );
}
