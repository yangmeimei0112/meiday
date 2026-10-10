import 'package:drift/drift.dart';

@DataClassName('SyncOutboxData')
class SyncOutbox extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get targetTable => text().named('table_name')(); // Target table name
  TextColumn get recordId => text()(); // Entity primary key
  TextColumn get action => text()(); // 'INSERT', 'UPDATE', 'DELETE'
  TextColumn get payloadJson => text()(); // Serialized JSON payload
  DateTimeColumn get clientTimestamp => dateTime()(); // LWW timestamp
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, processing, failed, synced
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
