import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../domain/entities/sync_state.dart';
import '../domain/repositories/outbox_repository.dart';
import '../domain/repositories/remote_sync_repository.dart';
import '../domain/services/idempotent_sync_engine.dart';
import '../domain/services/lww_conflict_resolver.dart';

class SyncCoordinator extends StateNotifier<SyncState> {
  final OutboxRepository _outboxRepo;
  final RemoteSyncRepository _remoteRepo;
  final AppDatabase _db;
  final IdempotentSyncEngine _syncEngine;
  final LwwConflictResolver _conflictResolver;
  final String _clientId;

  Timer? _periodicSyncTimer;
  final List<StreamSubscription> _realtimeSubscriptions = [];

  SyncCoordinator({
    required OutboxRepository outboxRepo,
    required RemoteSyncRepository remoteRepo,
    required AppDatabase db,
    required IdempotentSyncEngine syncEngine,
    required String clientId,
    LwwConflictResolver conflictResolver = const LwwConflictResolver(),
  })  : _outboxRepo = outboxRepo,
        _remoteRepo = remoteRepo,
        _db = db,
        _syncEngine = syncEngine,
        _clientId = clientId,
        _conflictResolver = conflictResolver,
        super(const SyncIdle());

  SyncState get currentState => state;

  void _emitState(SyncState nextState) {
    if (mounted) {
      state = nextState;
    }
  }

  /// Start automatic periodic background sync and realtime subscriptions
  void startAutoSync({
    required String userId,
    Duration interval = const Duration(seconds: 30),
  }) {
    stopAutoSync();

    // Trigger initial sync
    triggerManualSync(userId);

    // Setup periodic polling
    _periodicSyncTimer = Timer.periodic(interval, (_) {
      triggerManualSync(userId);
    });

    // Setup realtime subscriptions
    _subscribeRealtimeTable('calendar_events');
    _subscribeRealtimeTable('calendar_spaces');
  }

  void stopAutoSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    for (final sub in _realtimeSubscriptions) {
      sub.cancel();
    }
    _realtimeSubscriptions.clear();
  }

  /// Trigger on-demand sync push and pull
  Future<SyncState> triggerManualSync(String userId) async {
    final pendingCount = await _outboxRepo.getPendingCount();
    _emitState(SyncInProgress(totalCount: pendingCount, processedCount: 0));

    final result = await _syncEngine.syncPendingOutbox(userId: userId);
    _emitState(result);
    return result;
  }

  void _subscribeRealtimeTable(String tableName) {
    final sub = _remoteRepo.watchRealtimeTableChanges(tableName).listen(
      (change) async {
        await _handleRemoteRealtimeChange(tableName, change);
      },
      onError: (e) {
        debugPrint('Error in realtime subscription for $tableName: $e');
      },
    );
    _realtimeSubscriptions.add(sub);
  }

  /// Apply remote change to local SQLite using LWW conflict resolution
  Future<void> _handleRemoteRealtimeChange(
    String tableName,
    Map<String, dynamic> change,
  ) async {
    final eventType = change['event_type'] as String?;
    final newRecord = change['new'] as Map<String, dynamic>?;

    if (newRecord == null || eventType == 'DELETE') {
      return;
    }

    if (tableName == 'calendar_events') {
      final id = newRecord['id'] as String;
      final remoteUpdatedStr = newRecord['updated_at'] as String;
      final remoteUpdatedAt = DateTime.parse(remoteUpdatedStr);
      final remoteVersion = newRecord['version'] as int? ?? 1;

      final localRow = await (_db.select(_db.calendarEvents)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      if (localRow == null) {
        // Record does not exist locally -> insert directly
        await _db.into(_db.calendarEvents).insertOnConflictUpdate(
          _mapToCalendarEventCompanion(newRecord),
        );
      } else {
        // Conflict resolution via LWW
        final resolution = _conflictResolver.resolve<Map<String, dynamic>>(
          localData: {'id': localRow.id},
          remoteData: newRecord,
          localUpdatedAt: localRow.updatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
          localVersion: localRow.version,
          remoteVersion: remoteVersion,
          localClientId: _clientId,
          remoteClientId: 'remote',
        );

        if (resolution.isRemoteWinner) {
          await _db.into(_db.calendarEvents).insertOnConflictUpdate(
            _mapToCalendarEventCompanion(newRecord),
          );
        }
      }
    }
  }

  CalendarEventsCompanion _mapToCalendarEventCompanion(Map<String, dynamic> r) {
    return CalendarEventsCompanion.insert(
      id: r['id'] as String,
      userId: r['user_id'] as String? ?? 'guest',
      title: r['title'] as String? ?? '未命名行程',
      description: Value(r['description'] as String?),
      location: Value(r['location'] as String?),
      startTime: Value(r['start_time'] != null
          ? DateTime.parse(r['start_time'] as String)
          : null),
      endTime: Value(r['end_time'] != null
          ? DateTime.parse(r['end_time'] as String)
          : null),
      isAllDay: Value(r['is_all_day'] as bool? ?? false),
      isAnchored: Value(r['is_anchored'] as bool? ?? false),
      status: Value(r['status'] as String? ?? 'pending'),
      priority: Value(r['priority'] as int? ?? 0),
      estimatedMinutes: Value(r['estimated_minutes'] as int? ?? 30),
      actualMinutes: Value(r['actual_minutes'] as int? ?? 0),
      color: Value(r['color'] as int?),
      recurrenceRule: Value(r['recurrence_rule'] as String?),
      taskScore: Value((r['task_score'] as num?)?.toDouble() ?? 0.0),
      version: Value(r['version'] as int? ?? 1),
      createdAt: r['created_at'] != null
          ? DateTime.parse(r['created_at'] as String)
          : DateTime.now(),
      updatedAt: r['updated_at'] != null
          ? DateTime.parse(r['updated_at'] as String)
          : DateTime.now(),
      isDeleted: Value(r['is_deleted'] as bool? ?? false),
    );
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
