import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/calendar_spaces_table.dart';

part 'space_dao.g.dart';

@DriftAccessor(tables: [CalendarSpaces])
class SpaceDao extends DatabaseAccessor<AppDatabase> with _$SpaceDaoMixin {
  SpaceDao(super.db);

  Stream<List<CalendarSpaceData>> watchAllSpaces() {
    return (select(calendarSpaces)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<CalendarSpaceData?> getDefaultSpace() {
    return (select(calendarSpaces)
          ..where((t) => t.isDefault.equals(true) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<int> insertSpace(CalendarSpacesCompanion companion) {
    return into(calendarSpaces).insert(companion);
  }

  Future<bool> updateSpace(CalendarSpacesCompanion companion) {
    return update(calendarSpaces).replace(companion);
  }

  Future<int> softDeleteSpace(String id) {
    return (update(calendarSpaces)..where((t) => t.id.equals(id))).write(
      CalendarSpacesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
