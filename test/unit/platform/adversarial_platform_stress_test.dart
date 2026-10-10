import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/audio_service.dart';
import 'package:smart_calendar_hub/core/platform/notification_service.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_calendar_hub/core/platform/tray_service.dart';
import 'package:smart_calendar_hub/core/platform/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureStorageService Adversarial Stress Tests', () {
    late InMemorySecureStorageService storage;

    setUp(() {
      storage = InMemorySecureStorageService();
    });

    test('Edge case: empty key string write, read, and delete', () async {
      await storage.write(key: '', value: 'empty_key_payload');
      expect(await storage.containsKey(key: ''), isTrue);
      expect(await storage.read(key: ''), equals('empty_key_payload'));

      final all = await storage.readAll();
      expect(all[''], equals('empty_key_payload'));

      await storage.delete(key: '');
      expect(await storage.containsKey(key: ''), isFalse);
      expect(await storage.read(key: ''), isNull);
    });

    test('Edge case: empty value string vs non-existent key', () async {
      await storage.write(key: 'empty_val_key', value: '');
      expect(await storage.containsKey(key: 'empty_val_key'), isTrue);
      expect(await storage.read(key: 'empty_val_key'), equals(''));
      expect(await storage.read(key: 'completely_nonexistent'), isNull);
    });

    test('Edge case: deletion of nonexistent key does not throw', () async {
      expect(() async => await storage.delete(key: 'non_existent_key_xyz'), returnsNormally);
      expect(await storage.containsKey(key: 'non_existent_key_xyz'), isFalse);
    });

    test('Stress test: rapid overwriting with variable lengths and special characters', () async {
      const key = 'session_token';
      final values = [
        'initial',
        'long_token_${'A' * 2000}',
        'unicode_emoji_測試_🚀_📅',
        'sql_payload_\'; DROP TABLE users; --',
        'json_{"token":"xyz","roles":["admin","guest"]}',
        'newline_and_null_\n\r\t',
      ];

      for (final val in values) {
        await storage.write(key: key, value: val);
        expect(await storage.read(key: key), equals(val));
      }

      expect(storage.entryCount, equals(1));
    });

    test('Stress test: massive key scale (1,000 keys) and deleteAll clearing', () async {
      for (int i = 0; i < 1000; i++) {
        await storage.write(key: 'key_$i', value: 'val_$i');
      }
      expect(storage.entryCount, equals(1000));
      expect(await storage.containsKey(key: 'key_500'), isTrue);

      await storage.deleteAll();
      expect(storage.entryCount, equals(0));
      expect(await storage.read(key: 'key_500'), isNull);
      expect(await storage.readAll(), isEmpty);

      // Verify storage is still functional after deleteAll
      await storage.write(key: 'post_delete_key', value: 'resumed');
      expect(await storage.read(key: 'post_delete_key'), equals('resumed'));
    });

    test('Immutability: mutating readAll() map throws UnsupportedError', () async {
      await storage.write(key: 'k1', value: 'v1');
      final map = await storage.readAll();
      expect(() => map['k1'] = 'mutated', throwsUnsupportedError);
      expect(() => map.remove('k1'), throwsUnsupportedError);
    });
  });

  group('NotificationService Adversarial Stress Tests', () {
    late MockNotificationService notifications;

    setUp(() {
      notifications = MockNotificationService();
    });

    test('Edge case: scheduling notifications with past timestamps is preserved', () async {
      final pastDate = DateTime(2000, 1, 1, 12, 0);
      await notifications.scheduleNotification(
        id: 99,
        title: 'Past Event',
        body: 'Missed Alarm',
        scheduledTime: pastDate,
      );

      final pending = await notifications.getPendingNotifications();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(99));
      expect(pending.first.scheduledTime, equals(pastDate));
    });

    test('Edge case: cancel by non-existent ID does not throw and leaves other items intact', () async {
      await notifications.showNotification(id: 1, title: 'Item 1', body: 'Body 1');
      await notifications.scheduleNotification(
        id: 2,
        title: 'Item 2',
        body: 'Body 2',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(() async => await notifications.cancelNotification(99999), returnsNormally);
      expect(notifications.activeNotifications.length, equals(1));
      expect(notifications.scheduledNotifications.length, equals(1));
    });

    test('Edge case: cancelAll cleanses active, scheduled, and collapse-tracked notifications', () async {
      for (int i = 0; i < 10; i++) {
        await notifications.showNotification(
          id: i,
          title: 'Active $i',
          body: 'B $i',
          collapseId: 'chan_${i % 2}',
        );
        await notifications.scheduleNotification(
          id: 100 + i,
          title: 'Sched $i',
          body: 'B $i',
          scheduledTime: DateTime.now().add(Duration(minutes: i + 1)),
          collapseId: 'sched_chan_${i % 2}',
        );
      }

      await notifications.cancelAll();
      expect(notifications.activeNotifications, isEmpty);
      expect(notifications.scheduledNotifications, isEmpty);
      expect(await notifications.getPendingNotifications(), isEmpty);
    });

    test('Stress test: collapseId folding prevents unbounded notification growth', () async {
      const collapseGroup = 'sync_updates';
      for (int i = 0; i < 50; i++) {
        await notifications.showNotification(
          id: i,
          title: 'Sync Update $i',
          body: 'Progress $i%',
          collapseId: collapseGroup,
        );
      }

      // Because collapseId matches, previous notifications are collapsed
      expect(notifications.activeNotifications.length, equals(1));
      expect(notifications.activeNotifications.first.id, equals(49));
      expect(notifications.activeNotifications.first.title, equals('Sync Update 49'));
    });

    test('Edge case: cancelByCollapseId with nonexistent collapseId is safe', () async {
      await notifications.showNotification(id: 1, title: 'T', body: 'B', collapseId: 'valid_id');
      expect(() async => await notifications.cancelByCollapseId('invalid_id'), returnsNormally);
      expect(notifications.activeNotifications.length, equals(1));
    });
  });

  group('AudioService Adversarial Stress Tests', () {
    late MockAudioService audio;

    setUp(() {
      audio = MockAudioService();
    });

    test('Edge case: pause and resume without prior play remains idle', () async {
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);

      await audio.pauseWhiteNoise();
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);

      // Resuming when no track has ever been loaded must NOT set isPlaying = true
      await audio.resumeWhiteNoise();
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);
    });

    test('Edge case: stop state clears track and prevents subsequent resume', () async {
      await audio.playWhiteNoise('rain_sound');
      expect(audio.isPlaying, isTrue);
      expect(audio.currentTrackId, equals('rain_sound'));

      await audio.stopWhiteNoise();
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);

      // Resuming after explicit stop must be a no-op because track was cleared
      await audio.resumeWhiteNoise();
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);
    });

    test('Stress test: rapid concurrent sound effect triggers', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(audio.playSoundEffect('assets/audio/tick_$i.mp3'));
      }
      await Future.wait(futures);

      expect(audio.playedSoundEffects.length, equals(100));
      expect(audio.playedSoundEffects.first, equals('assets/audio/tick_0.mp3'));
      expect(audio.playedSoundEffects.last, equals('assets/audio/tick_99.mp3'));
    });

    test('Edge case: volume boundary clamping under extreme inputs', () async {
      await audio.setVolume(-999.0);
      expect(audio.currentVolume, equals(0.0));

      await audio.setVolume(999.0);
      expect(audio.currentVolume, equals(1.0));

      await audio.playWhiteNoise('waves', volume: 5.0);
      expect(audio.currentVolume, equals(1.0));

      await audio.playWhiteNoise('waves', volume: -0.5);
      expect(audio.currentVolume, equals(0.0));
    });

    test('Stress test: rapid track switching keeps accurate current track', () async {
      final tracks = ['rain', 'fan', 'forest', 'white_noise', 'waves'];
      for (final t in tracks) {
        await audio.playWhiteNoise(t);
        expect(audio.currentTrackId, equals(t));
        expect(audio.isPlaying, isTrue);
      }
    });
  });

  group('TrayService Adversarial Stress Tests', () {
    late MockTrayService tray;

    setUp(() {
      tray = MockTrayService();
    });

    test('Edge case: double/multiple event listeners on broadcast stream receive all events', () async {
      final listener1Events = <TrayEvent>[];
      final listener2Events = <TrayEvent>[];

      final sub1 = tray.onTrayEvent.listen(listener1Events.add);
      final sub2 = tray.onTrayEvent.listen(listener2Events.add);

      tray.simulateTrayEvent(TrayEventType.click);
      tray.simulateTrayEvent(TrayEventType.rightClick);
      tray.simulateTrayEvent(TrayEventType.doubleClick);

      await Future.delayed(Duration.zero);

      expect(listener1Events.length, equals(3));
      expect(listener2Events.length, equals(3));
      expect(listener1Events.map((e) => e.type).toList(), equals([
        TrayEventType.click,
        TrayEventType.rightClick,
        TrayEventType.doubleClick,
      ]));
      expect(listener2Events.map((e) => e.type).toList(), equals(listener1Events.map((e) => e.type).toList()));

      // Cancel sub1, simulate another event, verify sub2 still receives it
      await sub1.cancel();
      tray.simulateTrayEvent(TrayEventType.click);
      await Future.delayed(Duration.zero);

      expect(listener1Events.length, equals(3));
      expect(listener2Events.length, equals(4));

      await sub2.cancel();
    });

    test('Edge case: firing unhandled events with zero listeners does not throw', () {
      expect(() => tray.simulateTrayEvent(TrayEventType.click), returnsNormally);
      expect(() => tray.simulateTrayEvent(TrayEventType.doubleClick), returnsNormally);
      expect(() => tray.simulateTrayEvent(TrayEventType.rightClick), returnsNormally);
    });

    test('Stress test: rapid toggleMiniCalendar parity consistency', () async {
      expect(await tray.isMiniCalendarVisible(), isFalse);

      for (int i = 0; i < 50; i++) {
        await tray.toggleMiniCalendar();
      }
      // 50 toggles from false should end at false
      expect(await tray.isMiniCalendarVisible(), isFalse);

      await tray.toggleMiniCalendar();
      // 51st toggle should be true
      expect(await tray.isMiniCalendarVisible(), isTrue);
    });

    test('Edge case: destroy and re-initialize tray resets properties cleanly', () async {
      await tray.initializeTray(tooltip: 'Init Tip');
      await tray.setBadge(99);
      await tray.showMiniCalendar();

      await tray.destroyTray();
      expect(tray.isInitialized, isFalse);
      expect(tray.currentTooltip, isEmpty);
      expect(tray.currentBadgeCount, equals(0));
      expect(await tray.isMiniCalendarVisible(), isFalse);

      // Re-initialize
      await tray.initializeTray(tooltip: 'Reinitialized Tip');
      expect(tray.isInitialized, isTrue);
      expect(tray.currentTooltip, equals('Reinitialized Tip'));
    });
  });

  group('WidgetSyncService Adversarial Stress Tests', () {
    late MockWidgetSyncService widgetService;

    setUp(() {
      widgetService = MockWidgetSyncService();
    });

    test('Stress test: massive payload (1,000 keys with nested collections)', () async {
      final massivePayload = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };
      for (int i = 0; i < 1000; i++) {
        massivePayload['event_$i'] = {
          'id': 'evt_$i',
          'title': 'Very Long Title For Event #$i ' * 5,
          'priority': i % 3,
          'tags': ['work', 'calendar', 'important'],
        };
      }

      await widgetService.updateTodaySnapshot(massivePayload);
      final cached = await widgetService.getCachedSnapshot();

      expect(cached, isNotNull);
      expect(cached!.length, equals(1002));
      expect(cached['event_999']['id'], equals('evt_999'));
    });

    test('Edge case: corrupted payload with special values and empty map', () async {
      final corruptedPayload = <String, dynamic>{
        'empty_string': '',
        'null_value': null,
        'special_chars': '\n\t\r\u0000<script>alert("xss")</script>',
        'extreme_int': -9223372036854775808,
        'nested_empty_list': <dynamic>[],
        'nested_empty_map': <String, dynamic>{},
      };

      await widgetService.updateTodaySnapshot(corruptedPayload);
      final cached = await widgetService.getCachedSnapshot();

      expect(cached, isNotNull);
      expect(cached!['null_value'], isNull);
      expect(cached['extreme_int'], equals(-9223372036854775808));
      expect(cached['special_chars'], contains('script'));

      // Empty map update
      await widgetService.updateTodaySnapshot({});
      final emptySnapshot = await widgetService.getCachedSnapshot();
      expect(emptySnapshot, isNotNull);
      expect(emptySnapshot, isEmpty);

      // Clear snapshot
      await widgetService.clearSnapshot();
      expect(await widgetService.getCachedSnapshot(), isNull);
    });

    test('Stress test: rapid concurrent refreshWidgets increments call count accurately', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 50; i++) {
        futures.add(widgetService.refreshWidgets());
      }
      await Future.wait(futures);

      expect(widgetService.refreshCallCount, equals(50));
    });
  });

  group('Riverpod Container Isolation Adversarial Stress Tests', () {
    test('Provider overrides in Container A never leak to Container B or Default Container', () async {
      final storageOverrideA = InMemorySecureStorageService();
      final audioOverrideA = MockAudioService();

      final storageOverrideB = InMemorySecureStorageService();
      final audioOverrideB = MockAudioService();

      final containerA = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storageOverrideA),
          audioServiceProvider.overrideWithValue(audioOverrideA),
        ],
      );
      addTearDown(containerA.dispose);

      final containerB = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storageOverrideB),
          audioServiceProvider.overrideWithValue(audioOverrideB),
        ],
      );
      addTearDown(containerB.dispose);

      final containerDefault = ProviderContainer();
      addTearDown(containerDefault.dispose);

      // Mutate container A services
      await containerA.read(secureStorageServiceProvider).write(key: 'token', value: 'token_A');
      await containerA.read(audioServiceProvider).playWhiteNoise('track_A');

      // Verify container B is completely isolated
      expect(await containerB.read(secureStorageServiceProvider).read(key: 'token'), isNull);
      expect(containerB.read(audioServiceProvider).isPlaying, isFalse);
      expect(containerB.read(audioServiceProvider).currentTrackId, isNull);

      // Verify default container is completely isolated and got fresh instances
      expect(await containerDefault.read(secureStorageServiceProvider).read(key: 'token'), isNull);
      expect(containerDefault.read(audioServiceProvider).isPlaying, isFalse);

      // Mutate container B services
      await containerB.read(secureStorageServiceProvider).write(key: 'token', value: 'token_B');
      expect(await containerA.read(secureStorageServiceProvider).read(key: 'token'), equals('token_A'));
      expect(await containerB.read(secureStorageServiceProvider).read(key: 'token'), equals('token_B'));
    });

    test('Simulating consecutive test runs: container disposal cleans up cleanly', () async {
      for (int run = 0; run < 5; run++) {
        final container = ProviderContainer(
          overrides: [
            secureStorageServiceProvider.overrideWithValue(InMemorySecureStorageService()),
          ],
        );
        final storage = container.read(secureStorageServiceProvider);
        final notifications = container.read(notificationServiceProvider) as MockNotificationService;

        // Confirm pristine initial state on each run
        expect(await storage.readAll(), isEmpty, reason: 'Run $run storage was not empty');
        expect(notifications.activeNotifications, isEmpty, reason: 'Run $run notifications not empty');

        // Pollute state
        await storage.write(key: 'run_key', value: 'run_value_$run');
        await notifications.showNotification(id: run, title: 'T$run', body: 'B$run');

        // Dispose container at end of run
        container.dispose();
      }
    });

    test('All 6 platform providers instantiate distinct decoupled objects per container', () {
      final c1 = ProviderContainer();
      addTearDown(c1.dispose);
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);

      expect(identical(c1.read(secureStorageServiceProvider), c2.read(secureStorageServiceProvider)), isFalse);
      expect(identical(c1.read(ocrServiceProvider), c2.read(ocrServiceProvider)), isFalse);
      expect(identical(c1.read(notificationServiceProvider), c2.read(notificationServiceProvider)), isFalse);
      expect(identical(c1.read(trayServiceProvider), c2.read(trayServiceProvider)), isFalse);
      expect(identical(c1.read(audioServiceProvider), c2.read(audioServiceProvider)), isFalse);
      expect(identical(c1.read(widgetSyncServiceProvider), c2.read(widgetSyncServiceProvider)), isFalse);
    });
  });
}
