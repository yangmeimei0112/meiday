import 'package:clock/clock.dart';

class ClockUtils {
  /// Returns the current DateTime, respecting virtual clock test overrides.
  static DateTime now() => clock.now();

  /// Returns the current UTC DateTime.
  static DateTime nowUtc() => clock.now().toUtc();

  /// Returns the start of today (00:00:00.000).
  static DateTime startOfToday() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }

  /// Returns the end of today (23:59:59.999).
  static DateTime endOfToday() {
    final current = now();
    return DateTime(current.year, current.month, current.day, 23, 59, 59, 999);
  }
}
