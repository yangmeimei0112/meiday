import 'package:drift/drift.dart';

@DataClassName('CalendarSpaceData')
class CalendarSpaces extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()(); // Owner user ID or 'guest'
  TextColumn get name => text()(); // '個人', '伴侶', '家庭', '工作'
  TextColumn get type => text()(); // 'personal', 'couple', 'family', 'project'
  IntColumn get color => integer()(); // 32-bit ARGB hex
  TextColumn get icon => text().nullable()(); // Material icon name or emoji
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
