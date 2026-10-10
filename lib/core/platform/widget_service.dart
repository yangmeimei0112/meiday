abstract class WidgetSyncService {
  Future<void> updateTodaySnapshot(Map<String, dynamic> snapshotData);
  Future<void> refreshWidgets();
  Future<Map<String, dynamic>?> getCachedSnapshot();
  Future<void> clearSnapshot();
}

class MockWidgetSyncService implements WidgetSyncService {
  Map<String, dynamic>? _cachedSnapshot;
  int refreshCallCount = 0;

  @override
  Future<void> updateTodaySnapshot(Map<String, dynamic> snapshotData) async {
    _cachedSnapshot = Map<String, dynamic>.from(snapshotData);
  }

  @override
  Future<void> refreshWidgets() async {
    refreshCallCount++;
  }

  @override
  Future<Map<String, dynamic>?> getCachedSnapshot() async {
    return _cachedSnapshot != null
        ? Map<String, dynamic>.from(_cachedSnapshot!)
        : null;
  }

  @override
  Future<void> clearSnapshot() async {
    _cachedSnapshot = null;
  }

  void reset() {
    _cachedSnapshot = null;
    refreshCallCount = 0;
  }
}
