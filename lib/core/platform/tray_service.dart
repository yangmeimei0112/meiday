import 'dart:async';

enum TrayEventType {
  click,
  doubleClick,
  rightClick,
}

class TrayEvent {
  final TrayEventType type;
  final DateTime timestamp;

  const TrayEvent(this.type, this.timestamp);
}

abstract class TrayService {
  Future<void> initializeTray({String? tooltip, String? iconPath});
  Future<void> setToolTip(String tooltip);
  Future<void> setBadge(int count);
  Future<void> showMiniCalendar();
  Future<void> hideMiniCalendar();
  Future<void> toggleMiniCalendar();
  Future<bool> isMiniCalendarVisible();
  Future<void> destroyTray();
  Stream<TrayEvent> get onTrayEvent;
}

class MockTrayService implements TrayService {
  bool isInitialized = false;
  String currentTooltip = '';
  int currentBadgeCount = 0;
  bool _isMiniCalendarVisible = false;

  final StreamController<TrayEvent> _eventController =
      StreamController<TrayEvent>.broadcast();

  @override
  Stream<TrayEvent> get onTrayEvent => _eventController.stream;

  @override
  Future<void> initializeTray({String? tooltip, String? iconPath}) async {
    isInitialized = true;
    if (tooltip != null) currentTooltip = tooltip;
  }

  @override
  Future<void> setToolTip(String tooltip) async {
    currentTooltip = tooltip;
  }

  @override
  Future<void> setBadge(int count) async {
    currentBadgeCount = count;
  }

  @override
  Future<void> showMiniCalendar() async {
    _isMiniCalendarVisible = true;
  }

  @override
  Future<void> hideMiniCalendar() async {
    _isMiniCalendarVisible = false;
  }

  @override
  Future<void> toggleMiniCalendar() async {
    _isMiniCalendarVisible = !_isMiniCalendarVisible;
  }

  @override
  Future<bool> isMiniCalendarVisible() async => _isMiniCalendarVisible;

  @override
  Future<void> destroyTray() async {
    isInitialized = false;
    _isMiniCalendarVisible = false;
    currentBadgeCount = 0;
    currentTooltip = '';
  }

  void simulateTrayEvent(TrayEventType type) {
    _eventController.add(TrayEvent(type, DateTime.now()));
  }

  void reset() {
    isInitialized = false;
    currentTooltip = '';
    currentBadgeCount = 0;
    _isMiniCalendarVisible = false;
  }
}
