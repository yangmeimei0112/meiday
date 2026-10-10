class AppConstants {
  static const String appName = 'ChronoHub';
  static const String appVersion = '1.0.0';

  // Workload Capacity Limits (PRD §2)
  static const int defaultDailyCapacityMinutes = 480; // 8 hours soft warning limit
  static const int capacityWarningThresholdMinutes = 480;

  // Scheduling Defaults
  static const int defaultTimeBlockMinutes = 30;
  static const int calendarSnapIntervalMinutes = 15;
  static const int minBufferCompressionMinutes = 5;

  // GTD Pomodoro Defaults (PRD §2, §7)
  static const int defaultPomodoroWorkMinutes = 25;
  static const int defaultPomodoroShortBreakMinutes = 5;
  static const int defaultPomodoroLongBreakMinutes = 15;
  static const int defaultPomodoroLongBreakInterval = 4;

  // Desktop Dimensions & Hotkeys (PRD §4.4)
  static const double miniTrayWidth = 360.0;
  static const double miniTrayHeight = 520.0;
  static const String defaultGlobalHotkey = 'Win+Shift+C';

  // Native Widget Snapshot Constraints
  static const int maxWidgetSnapshotSizeBytes = 5 * 1024 * 1024; // <5MB
}
