import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/migrations/migration_models.dart';

class MigrationConflictDetector {
  /// Evaluates whether guest data exists and whether conflict resolution is required.
  static Future<MigrationScenario> detectScenario({
    required AppDatabase guestDb,
    required AppDatabase userDb,
    required bool isNewRegistration,
  }) async {
    // 1. Check if guestDb contains active user data
    final hasGuestData = await checkHasGuestData(guestDb);
    if (!hasGuestData) {
      return MigrationScenario.noGuestData;
    }

    // 2. If user explicitly registered a brand-new account -> auto-migrate directly
    if (isNewRegistration) {
      return MigrationScenario.brandNewAccount;
    }

    // 3. For existing login: inspect target userDb
    final hasUserData = await checkHasUserData(userDb);
    if (hasUserData) {
      return MigrationScenario.existingAccountConflict;
    } else {
      return MigrationScenario.brandNewAccount;
    }
  }

  static Future<bool> checkHasGuestData(AppDatabase guestDb) async {
    final eventCount = await (guestDb.select(guestDb.calendarEvents)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    if (eventCount.isNotEmpty) return true;

    final keepCount = await (guestDb.select(guestDb.keepItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    if (keepCount.isNotEmpty) return true;

    final customSpaces = await (guestDb.select(guestDb.calendarSpaces)
          ..where((t) => t.isDefault.equals(false) & t.isDeleted.equals(false)))
        .get();
    if (customSpaces.isNotEmpty) return true;

    return false;
  }

  static Future<bool> checkHasUserData(AppDatabase userDb) async {
    final events = await (userDb.select(userDb.calendarEvents)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    if (events.isNotEmpty) return true;

    final keepItems = await (userDb.select(userDb.keepItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    if (keepItems.isNotEmpty) return true;

    return false;
  }
}
