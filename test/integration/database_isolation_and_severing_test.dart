import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/database_lifecycle_coordinator.dart';
import 'package:smart_calendar_hub/core/database/connection/native_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/utils/hash_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chronohub_integration_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('Integration Test Suite 1: Physical File System Isolation on Disk', () {
    test('guest.db and user_{sha256}.db physically exist as separate files on disk', () async {
      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );

      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(nativeFactory),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = container.read(databaseLifecycleCoordinatorProvider);

      // 1. Guest writes data
      final guestDb = coordinator.activeDatabase;
      final now = DateTime.now();
      await guestDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-guest-disk',
          userId: 'guest',
          name: '訪客專屬空間',
          type: 'personal',
          color: 0xFF123456,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify guest.db exists on disk
      final guestFile = File(p.join(tempDir.path, 'ChronoHub', 'databases', 'guest.db'));
      expect(await guestFile.exists(), isTrue);
      expect(await guestFile.length(), greaterThan(0));

      // 2. Switch to User Alice
      const aliceId = 'user-alice-123';
      final expectedAliceFilename = HashUtils.resolveDatabaseName(aliceId);
      expect(expectedAliceFilename.length, equals(72)); // user_ + 64 hex + .db

      final aliceDb = await coordinator.switchSession(const AuthenticatedDbAuthState(aliceId));
      expect(identical(guestDb, aliceDb), isFalse);

      // Verify Alice database is initially empty
      final aliceSpacesInit = await aliceDb.spaceDao.watchAllSpaces().first;
      expect(aliceSpacesInit.isEmpty, isTrue);

      // Alice writes data
      await aliceDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-alice-disk',
          userId: aliceId,
          name: 'Alice 機密空間',
          type: 'personal',
          color: 0xFFABCDEF,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify Alice file exists on disk
      final aliceFile = File(p.join(tempDir.path, 'ChronoHub', 'databases', expectedAliceFilename));
      expect(await aliceFile.exists(), isTrue);
      expect(await aliceFile.length(), greaterThan(0));

      // 3. Sever and return to Guest
      final returnedGuestDb = await coordinator.severAndSwitchToGuest();
      expect(identical(aliceDb, returnedGuestDb), isFalse);

      // Verify Guest sees only guest space
      final returnedGuestSpaces = await returnedGuestDb.spaceDao.watchAllSpaces().first;
      expect(returnedGuestSpaces.length, equals(1));
      expect(returnedGuestSpaces.first.id, equals('sp-guest-disk'));
      expect(returnedGuestSpaces.any((s) => s.id == 'sp-alice-disk'), isFalse);
    });

    test('Path traversal attempts are completely sanitized by 64-char SHA-256', () async {
      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );

      final maliciousIds = [
        '../../../../windows/system32/cmd.exe',
        r'..\..\..\etc\passwd',
        'foo/bar/baz/hack.db',
        'user\x00nullbyte',
      ];

      for (final badId in maliciousIds) {
        final resolvedName = HashUtils.resolveDatabaseName(badId);
        expect(resolvedName, startsWith('user_'));
        expect(resolvedName, endsWith('.db'));
        expect(resolvedName.contains('/'), isFalse);
        expect(resolvedName.contains(r'\'), isFalse);
        expect(resolvedName.contains('..'), isFalse);
        expect(resolvedName.length, equals(72));

        final targetFile = await nativeFactory.getDatabaseFile(resolvedName);
        expect(targetFile.parent.path, equals(p.join(tempDir.path, 'ChronoHub', 'databases')));
      }
    });
  });

  group('Integration Test Suite 2: Dynamic Severing & Stale Query Invalidation', () {
    test('Queries on severed database handle fail immediately post-logout', () async {
      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(nativeFactory),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = container.read(databaseLifecycleCoordinatorProvider);

      // Log in as Bob
      const bobId = 'user-bob-999';
      final bobDb = await coordinator.switchSession(const AuthenticatedDbAuthState(bobId));
      final now = DateTime.now();

      await bobDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-bob-secret',
          userId: bobId,
          title: 'Bob 機密行程',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify read works before logout
      final eventsBefore = await bobDb.eventDao.watchAllEvents().first;
      expect(eventsBefore.length, equals(1));

      // Trigger safe logout & severing
      final guestDb = await coordinator.severAndSwitchToGuest();

      // Bob's old handle MUST be severed and reject any reads or writes
      expect(
        () async => await bobDb.eventDao.watchAllEvents().first,
        throwsA(anything),
        reason: 'Reads on severed database must throw',
      );

      expect(
        () async => await bobDb.eventDao.insertEvent(
          CalendarEventsCompanion.insert(
            id: 'ev-bob-rogue',
            userId: bobId,
            title: 'Rogue write after logout',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Writes on severed database must throw',
      );

      // Fresh guest DB works normally
      final guestEvents = await guestDb.eventDao.watchAllEvents().first;
      expect(guestEvents.isEmpty, isTrue);
    });
  });

  group('Integration Test Suite 3: Multi-User Switching Matrix', () {
    test('Switching Guest -> User Alpha -> Guest -> User Beta -> User Alpha preserves isolation', () async {
      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(nativeFactory),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = container.read(databaseLifecycleCoordinatorProvider);
      final now = DateTime.now();

      // 1. Guest creates task
      final guestDb = coordinator.activeDatabase;
      await guestDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-guest-1',
          userId: 'guest',
          title: '訪客買牛奶',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Alpha logs in and creates task
      final alphaDb = await coordinator.switchSession(const AuthenticatedDbAuthState('alpha-uuid'));
      await alphaDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-alpha-1',
          userId: 'alpha-uuid',
          title: 'Alpha 財報會議',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Alpha logs out -> Guest verifies
      final guestDb2 = await coordinator.severAndSwitchToGuest();
      final guestEvents = await guestDb2.eventDao.watchAllEvents().first;
      expect(guestEvents.map((e) => e.id), equals(['ev-guest-1']));

      // 4. Beta logs in and creates task
      final betaDb = await coordinator.switchSession(const AuthenticatedDbAuthState('beta-uuid'));
      await betaDb.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-beta-1',
          userId: 'beta-uuid',
          title: 'Beta 專案審查',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final betaEvents = await betaDb.eventDao.watchAllEvents().first;
      expect(betaEvents.map((e) => e.id), equals(['ev-beta-1']));

      // 5. Alpha logs back in
      final alphaDb2 = await coordinator.switchSession(const AuthenticatedDbAuthState('alpha-uuid'));
      final alphaEvents = await alphaDb2.eventDao.watchAllEvents().first;
      expect(alphaEvents.map((e) => e.id), equals(['ev-alpha-1']));
    });
  });

  group('Integration Test Suite 4: Rapid Flapping & Concurrency Resilience', () {
    test('30 rapid sequential transitions between sessions maintain consistency without deadlock', () async {
      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(nativeFactory),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = container.read(databaseLifecycleCoordinatorProvider);

      for (int i = 0; i < 30; i++) {
        if (i % 3 == 0) {
          await coordinator.severAndSwitchToGuest();
        } else if (i % 3 == 1) {
          await coordinator.switchSession(const AuthenticatedDbAuthState('user-a'));
        } else {
          await coordinator.switchSession(const AuthenticatedDbAuthState('user-b'));
        }
      }

      // Final state check
      final finalDb = coordinator.activeDatabase;
      expect(finalDb, isNotNull);
      final spaces = await finalDb.spaceDao.watchAllSpaces().first;
      expect(spaces, isNotNull);
    });
  });
}
