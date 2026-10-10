import 'dart:async';
import 'dart:convert';
import '../../domain/entities/batch_sync_payload.dart';
import '../../domain/entities/outbox_mutation.dart';
import 'supabase_sync_client.dart';

class MockSupabaseSyncClient implements SupabaseSyncClient {
  bool isNetworkAvailable = true;
  String currentUserId = 'user-test-default-id';

  // Remote database storage: table -> (recordId -> recordMap)
  final Map<String, Map<String, Map<String, dynamic>>> _remoteTables = {};

  // Idempotency cache: idempotencyKey -> BatchSyncResult
  final Map<String, BatchSyncResult> _processedIdempotencyKeys = {};

  // Realtime controllers per table
  final Map<String, StreamController<Map<String, dynamic>>> _streamControllers = {};

  MockSupabaseSyncClient() {
    _initTables();
  }

  void _initTables() {
    for (final table in [
      'calendar_spaces',
      'calendar_events',
      'event_space_links',
      'event_comments',
      'event_checklists',
      'keep_items',
      'user_devices',
    ]) {
      _remoteTables[table] = {};
    }
  }

  void reset() {
    _remoteTables.clear();
    _processedIdempotencyKeys.clear();
    _initTables();
    isNetworkAvailable = true;
  }

  Map<String, Map<String, dynamic>> getTableData(String table) =>
      Map.unmodifiable(_remoteTables[table] ?? {});

  @override
  Future<bool> ping() async => isNetworkAvailable;

  @override
  Future<void> upsert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    _ensureOnline();
    final id = data['id'] as String;
    final tableStore = _remoteTables.putIfAbsent(table, () => {});
    tableStore[id] = Map<String, dynamic>.from(data);

    // Broadcast realtime event
    _notifyRealtime(table, {
      'event_type': 'UPSERT',
      'table': table,
      'new': Map<String, dynamic>.from(data),
      'old': null,
    });
  }

  @override
  Future<void> delete({
    required String table,
    required String id,
  }) async {
    _ensureOnline();
    final tableStore = _remoteTables[table];
    final oldRecord = tableStore?.remove(id);

    _notifyRealtime(table, {
      'event_type': 'DELETE',
      'table': table,
      'new': null,
      'old': oldRecord ?? {'id': id},
    });
  }

  @override
  Future<List<Map<String, dynamic>>> query({
    required String table,
    required DateTime since,
    int limit = 100,
  }) async {
    _ensureOnline();
    final store = _remoteTables[table] ?? {};
    final results = <Map<String, dynamic>>[];

    for (final record in store.values) {
      final updatedStr = record['updated_at'] as String?;
      if (updatedStr != null) {
        final updatedAt = DateTime.parse(updatedStr);
        if (updatedAt.isAfter(since)) {
          results.add(Map<String, dynamic>.from(record));
        }
      } else {
        results.add(Map<String, dynamic>.from(record));
      }
      if (results.length >= limit) break;
    }
    return results;
  }

  @override
  Future<BatchSyncResult> executeBatchRpc(BatchSyncPayload payload) async {
    _ensureOnline();

    // Feature #43 Idempotent RPC Check:
    // If the idempotency key was already processed, return the cached result immediately!
    if (_processedIdempotencyKeys.containsKey(payload.idempotencyKey)) {
      return BatchSyncResult(
        idempotencyKey: payload.idempotencyKey,
        isSuccess: true,
        appliedCount: 0,
        skippedDuplicateCount: payload.mutations.length,
        errorMessage: 'Skipped duplicate batch replay via idempotency key',
      );
    }

    int applied = 0;
    final rejected = <String>[];

    for (final mutation in payload.mutations) {
      try {
        final table = mutation.tableName;
        final targetStore = _remoteTables.putIfAbsent(table, () => {});

        switch (mutation.action) {
          case SyncAction.insert:
          case SyncAction.update:
            final decoded = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
            targetStore[mutation.recordId] = decoded;
            applied++;
            _notifyRealtime(table, {
              'event_type': 'UPSERT',
              'table': table,
              'new': decoded,
            });
            break;
          case SyncAction.delete:
            targetStore.remove(mutation.recordId);
            applied++;
            _notifyRealtime(table, {
              'event_type': 'DELETE',
              'table': table,
              'old': {'id': mutation.recordId},
            });
            break;
        }
      } catch (e) {
        rejected.add(mutation.id);
      }
    }

    final result = BatchSyncResult(
      idempotencyKey: payload.idempotencyKey,
      isSuccess: rejected.isEmpty,
      appliedCount: applied,
      rejectedMutationIds: rejected,
    );

    _processedIdempotencyKeys[payload.idempotencyKey] = result;
    return result;
  }

  @override
  Stream<Map<String, dynamic>> realtimeStream(String table) {
    final controller = _streamControllers.putIfAbsent(
      table,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    return controller.stream;
  }

  void _notifyRealtime(String table, Map<String, dynamic> event) {
    final controller = _streamControllers[table];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  void _ensureOnline() {
    if (!isNetworkAvailable) {
      throw Exception('NetworkUnavailable: Cannot communicate with Supabase cloud');
    }
  }
}
