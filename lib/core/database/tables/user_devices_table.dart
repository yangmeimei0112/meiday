import 'package:drift/drift.dart';

@DataClassName('UserDeviceData')
class UserDevices extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()();
  TextColumn get deviceName => text()();
  TextColumn get platform => text()(); // 'windows', 'macos', 'ios', 'android', 'web'
  TextColumn get deviceToken => text()();
  DateTimeColumn get lastActiveAt => dateTime()();
  TextColumn get clientIp => text().nullable()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
