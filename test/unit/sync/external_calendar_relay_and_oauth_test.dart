import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/features/sync/data/datasources/desktop_oauth_service.dart';
import 'package:smart_calendar_hub/features/sync/domain/entities/external_calendar_event.dart';
import 'package:smart_calendar_hub/features/sync/domain/services/external_calendar_relay.dart';

void main() {
  group('External Calendar Relay & Desktop OAuth Tests (Feature #47 & #48)', () {
    test('ExternalCalendarRelayService performs bi-directional sync operations', () async {
      final relay = MockExternalCalendarRelayService();

      expect(await relay.hasCalendarPermissions(), isTrue);
      final calendars = await relay.getAvailableCalendars();
      expect(calendars.contains('primary'), isTrue);

      final newEvent = ExternalCalendarEvent(
        externalId: 'ext-google-1',
        calendarId: 'primary',
        source: ExternalCalendarSource.google,
        title: 'Project Kickoff',
        startTime: DateTime(2026, 10, 10, 15, 0),
        endTime: DateTime(2026, 10, 10, 16, 0),
        lastModified: DateTime.now(),
      );

      // Export event to device calendar
      final id = await relay.exportEventToDeviceCalendar(
        calendarId: 'primary',
        event: newEvent,
      );
      expect(id, equals('ext-google-1'));

      // Fetch events from device
      final fetched = await relay.fetchEventsFromDevice(
        rangeStart: DateTime(2026, 10, 10, 0, 0),
        rangeEnd: DateTime(2026, 10, 10, 23, 59),
        calendarId: 'primary',
      );
      expect(fetched.length, equals(1));
      expect(fetched.first.title, equals('Project Kickoff'));

      // Delete event from device calendar
      final deleted = await relay.deleteEventFromDeviceCalendar(
        calendarId: 'primary',
        externalEventId: 'ext-google-1',
      );
      expect(deleted, isTrue);

      final emptyList = await relay.fetchEventsFromDevice(
        rangeStart: DateTime(2026, 10, 10, 0, 0),
        rangeEnd: DateTime(2026, 10, 10, 23, 59),
      );
      expect(emptyList.isEmpty, isTrue);
    });

    test('DesktopOAuthService loopback flow exchanges code for token payload', () async {
      final oauth = MockDesktopOAuthService();

      final code = await oauth.acquireAuthCode(
        clientId: 'chronohub-test-client',
        scopes: ['https://www.googleapis.com/auth/calendar.events'],
      );
      expect(code, equals('mock_code_xyz123'));

      final tokenResponse = await oauth.exchangeCodeForTokens(
        clientId: 'chronohub-test-client',
        authCode: code,
      );
      expect(tokenResponse.containsKey('access_token'), isTrue);
      expect(tokenResponse['token_type'], equals('Bearer'));
    });
  });
}
