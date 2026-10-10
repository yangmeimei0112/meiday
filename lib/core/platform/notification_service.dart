class ScheduledNotificationItem {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String? payload;
  final String? collapseId;

  const ScheduledNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
    this.collapseId,
  });
}

abstract class NotificationService {
  Future<void> initialize();
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? collapseId,
  });
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String? collapseId,
  });
  Future<void> cancelNotification(int id);
  Future<void> cancelByCollapseId(String collapseId);
  Future<void> cancelAll();
  Future<List<ScheduledNotificationItem>> getPendingNotifications();
}

class MockNotificationService implements NotificationService {
  bool isInitialized = false;
  final List<ScheduledNotificationItem> _activeNotifications = [];
  final List<ScheduledNotificationItem> _scheduledNotifications = [];

  List<ScheduledNotificationItem> get activeNotifications =>
      List.unmodifiable(_activeNotifications);
  List<ScheduledNotificationItem> get scheduledNotifications =>
      List.unmodifiable(_scheduledNotifications);

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? collapseId,
  }) async {
    if (collapseId != null) {
      _activeNotifications.removeWhere((item) => item.collapseId == collapseId);
    }
    _activeNotifications.add(
      ScheduledNotificationItem(
        id: id,
        title: title,
        body: body,
        scheduledTime: DateTime.now(),
        payload: payload,
        collapseId: collapseId,
      ),
    );
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String? collapseId,
  }) async {
    if (collapseId != null) {
      _scheduledNotifications.removeWhere((item) => item.collapseId == collapseId);
    }
    _scheduledNotifications.add(
      ScheduledNotificationItem(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: payload,
        collapseId: collapseId,
      ),
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    _activeNotifications.removeWhere((item) => item.id == id);
    _scheduledNotifications.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> cancelByCollapseId(String collapseId) async {
    _activeNotifications.removeWhere((item) => item.collapseId == collapseId);
    _scheduledNotifications.removeWhere((item) => item.collapseId == collapseId);
  }

  @override
  Future<void> cancelAll() async {
    _activeNotifications.clear();
    _scheduledNotifications.clear();
  }

  @override
  Future<List<ScheduledNotificationItem>> getPendingNotifications() async {
    return List.unmodifiable(_scheduledNotifications);
  }

  void reset() {
    isInitialized = false;
    _activeNotifications.clear();
    _scheduledNotifications.clear();
  }
}
