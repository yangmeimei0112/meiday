import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_devices_table.dart';

part 'user_device_dao.g.dart';

@DriftAccessor(tables: [UserDevices])
class UserDeviceDao extends DatabaseAccessor<AppDatabase> with _$UserDeviceDaoMixin {
  UserDeviceDao(super.db);

  Stream<List<UserDeviceData>> watchDevices() {
    return (select(userDevices)
          ..orderBy([(t) => OrderingTerm(expression: t.lastActiveAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> upsertDevice(UserDevicesCompanion companion) {
    return into(userDevices).insertOnConflictUpdate(companion);
  }

  Future<int> removeDevice(String id) {
    return (delete(userDevices)..where((t) => t.id.equals(id))).go();
  }
}
