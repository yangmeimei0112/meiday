import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<int> enqueueMutation({
    required String id,
    required String tableName,
    required String recordId,
    required String action,
    required String payloadJson,
  }) {
    return into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        id: id,
        targetTable: tableName,
        recordId: recordId,
        action: action,
        payloadJson: payloadJson,
        clientTimestamp: DateTime.now(),
      ),
    );
  }

  Future<List<SyncOutboxData>> getPendingMutations({int limit = 50}) {
    return (select(syncOutbox)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm(expression: t.clientTimestamp)])
          ..limit(limit))
        .get();
  }

  Future<int> markStatus(String id, String status, {String? errorMessage}) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: Value(status),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  Stream<int> watchPendingCount() {
    return (select(syncOutbox)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed')))
        .watch()
        .map((list) => list.length);
  }
}
