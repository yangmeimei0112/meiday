// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keep_item_dao.dart';

// ignore_for_file: type=lint
mixin _$KeepItemDaoMixin on DatabaseAccessor<AppDatabase> {
  $KeepItemsTable get keepItems => attachedDatabase.keepItems;
  KeepItemDaoManager get managers => KeepItemDaoManager(this);
}

class KeepItemDaoManager {
  final _$KeepItemDaoMixin _db;
  KeepItemDaoManager(this._db);
  $$KeepItemsTableTableManager get keepItems =>
      $$KeepItemsTableTableManager(_db.attachedDatabase, _db.keepItems);
}
