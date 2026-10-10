// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_device_dao.dart';

// ignore_for_file: type=lint
mixin _$UserDeviceDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserDevicesTable get userDevices => attachedDatabase.userDevices;
  UserDeviceDaoManager get managers => UserDeviceDaoManager(this);
}

class UserDeviceDaoManager {
  final _$UserDeviceDaoMixin _db;
  UserDeviceDaoManager(this._db);
  $$UserDevicesTableTableManager get userDevices =>
      $$UserDevicesTableTableManager(_db.attachedDatabase, _db.userDevices);
}
