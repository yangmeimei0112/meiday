import '../entities/external_calendar_event.dart';

abstract class ExternalCalendarRelayService {
  Future<bool> hasCalendarPermissions();

  Future<bool> requestCalendarPermissions();

  Future<List<String>> getAvailableCalendars();

  Future<List<ExternalCalendarEvent>> fetchEventsFromDevice({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? calendarId,
  });

  Future<String> exportEventToDeviceCalendar({
    required String calendarId,
    required ExternalCalendarEvent event,
  });

  Future<bool> deleteEventFromDeviceCalendar({
    required String calendarId,
    required String externalEventId,
  });
}

class MockExternalCalendarRelayService implements ExternalCalendarRelayService {
  bool _hasPermission = true;
  final List<ExternalCalendarEvent> _deviceEvents = [];
  final List<String> _calendars = ['primary', 'work', 'personal'];

  void setHasPermission(bool val) => _hasPermission = val;

  void seedDeviceEvents(List<ExternalCalendarEvent> events) {
    _deviceEvents.clear();
    _deviceEvents.addAll(events);
  }

  @override
  Future<bool> hasCalendarPermissions() async => _hasPermission;

  @override
  Future<bool> requestCalendarPermissions() async {
    _hasPermission = true;
    return true;
  }

  @override
  Future<List<String>> getAvailableCalendars() async => List.unmodifiable(_calendars);

  @override
  Future<List<ExternalCalendarEvent>> fetchEventsFromDevice({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? calendarId,
  }) async {
    if (!_hasPermission) return [];
    return _deviceEvents.where((e) {
      if (calendarId != null && e.calendarId != calendarId) return false;
      return e.startTime.isBefore(rangeEnd) && e.endTime.isAfter(rangeStart);
    }).toList();
  }

  @override
  Future<String> exportEventToDeviceCalendar({
    required String calendarId,
    required ExternalCalendarEvent event,
  }) async {
    _deviceEvents.removeWhere((e) => e.externalId == event.externalId);
    _deviceEvents.add(event);
    return event.externalId;
  }

  @override
  Future<bool> deleteEventFromDeviceCalendar({
    required String calendarId,
    required String externalEventId,
  }) async {
    final before = _deviceEvents.length;
    _deviceEvents.removeWhere((e) => e.externalId == externalEventId);
    return _deviceEvents.length < before;
  }
}
