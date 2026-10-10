import 'package:drift/drift.dart';

@DataClassName('KeepItemData')
class KeepItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get content => text().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get tags => text().nullable()(); // Comma-separated or JSON
  TextColumn get convertedToEventId => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
