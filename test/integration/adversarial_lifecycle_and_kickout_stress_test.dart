import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smart_calendar_hub/core/database/app_database.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/database_lifecycle_coordinator.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/connection/native_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/core/utils/hash_utils.dart';
import 'package:smart_calendar_hub/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:smart_calendar_hub/features/auth/data/datasources/mock_session_realtime_datasource.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_state.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/kickout_event.dart';
import 'package:smart_calendar_hub/features/auth/presentation/providers/auth_providers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('chronohub_adversarial_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('Adversarial Stress Suite 1: Path Traversal & Injection Attack Hardening', () {
    test('Hostile inputs to HashUtils.resolveDatabaseName are strictly sanitized', () async {
      final nativeFactory = NativeDatabaseConnectionFactory(
        appDirectoryResolver: () async => tempDir,
      );

      final hostileInputs = <String?>[
        // Classic directory traversal
        '../../../bad',
        '../../../../etc/passwd',
        r'..\..\..\Windows\System32\cmd.exe',
        r'..\..\..\Windows\System32\drivers\etc\hosts',
        '....//....//....//hidden.db',
        '/var/data/stolen.db',
        'C:\\secrets.db',

        // Null-byte injection
        'admin\x00.db',
        'user\x00/../../etc/passwd',

        // Windows reserved devices
        'CON',
        'PRN',
        'AUX',
        'NUL',
        'COM1',
        'LPT1',

        // Collision spoofing attempts
        'guest.db',
        'user_guest.db',
        'user_0000000000000000000000000000000000000000000000000000000000000000.db',

        // Extreme length (buffer stress)
        'A' * 5000,
        '../' * 1000 + 'root',

        // Unicode / RTL override tricks
        'user_\u202Etxt.bd',
        'مرحبا/../../evil',
      ];

      final hex72Pattern = RegExp(r'^user_[a-f0-9]{64}\.db$');

      for (final input in hostileInputs) {
        final resolved = HashUtils.resolveDatabaseName(input);

        // Assert strictly matches 72 chars user_<64hex>.db format
        expect(
          hex72Pattern.hasMatch(resolved),
          isTrue,
          reason: 'Input "$input" failed format assertion: got "$resolved"',
        );
        expect(resolved.length, equals(72));

        // Assert no traversal or path separator characters
        expect(resolved.contains('/'), isFalse);
        expect(resolved.contains(r'\'), isFalse);
        expect(resolved.contains('..'), isFalse);
        expect(resolved.contains('\x00'), isFalse);

        // Verify physical file resolution on disk never escapes ChronoHub/databases directory
        final file = await nativeFactory.getDatabaseFile(resolved);
        final normalizedParent = p.normalize(file.parent.path);
        final expectedParent = p.normalize(p.join(tempDir.path, 'ChronoHub', 'databases'));
        expect(normalizedParent, equals(expectedParent));
        expect(file.path.startsWith(expectedParent), isTrue);
      }
    });

    test('Empty and whitespace variants safely resolve to guest.db without crashing', () {
      final guestVariants = <String?>[
        null,
        '',
        '   ',
        '\t',
        '\n',
        '\r\n',
        '   \t\n  ',
      ];

      for (final variant in guestVariants) {
        final resolved = HashUtils.resolveDatabaseName(variant);
        expect(resolved, equals('guest.db'));
      }
    });
  });

  group('Adversarial Stress Suite 2: Rapid Flapping & Concurrency Stress Test', () {
    test('50 rapid un-awaited session flapping transitions execute deterministically without deadlock', () async {
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

      // Flapping sequence: Guest -> UserA -> Guest -> UserB -> Guest -> ...
      final futures = <Future<AppDatabase>>[];
      for (int i = 0; i < 50; i++) {
        if (i % 3 == 0) {
          futures.add(coordinator.severAndSwitchToGuest());
        } else if (i % 3 == 1) {
          futures.add(coordinator.switchSession(const AuthenticatedDbAuthState('user-alpha')));
        } else {
          futures.add(coordinator.switchSession(const AuthenticatedDbAuthState('user-beta')));
        }
      }

      // Concurrently await all 50 flapping transitions
      final results = await Future.wait(futures);
      expect(results.length, equals(50));

      // 49 % 3 == 1 -> The final scheduled state was 'user-alpha'
      final finalDb = coordinator.activeDatabase;
      expect(finalDb, isNotNull);

      final currentAuth = container.read(currentAuthForDbProvider);
      expect(currentAuth.userId, equals('user-alpha'));

      // Active database is fully functional for read and write
      final now = DateTime.now();
      await finalDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-alpha-survivor',
          userId: 'user-alpha',
          name: 'Alpha Survivor Space',
          type: 'personal',
          color: 0xFF445566,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final spaces = await finalDb.spaceDao.watchAllSpaces().first;
      expect(spaces.any((s) => s.id == 'sp-alpha-survivor'), isTrue);
    });

    test('Data written during rapid interleaved flapping remains strictly isolated across tenants', () async {
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

      // Interleaved write cycles:
      // Cycle 1: Guest writes data
      final gDb1 = coordinator.activeDatabase;
      await gDb1.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-guest-cycle1',
          userId: 'guest',
          title: 'Guest Event 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Cycle 2: User Alpha writes data
      final aDb1 = await coordinator.switchSession(const AuthenticatedDbAuthState('user-alpha'));
      await aDb1.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-alpha-cycle1',
          userId: 'user-alpha',
          title: 'Alpha Event 1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Cycle 3: Guest sever
      final gDb2 = await coordinator.severAndSwitchToGuest();
      final gEvents = await gDb2.eventDao.watchAllEvents().first;
      expect(gEvents.map((e) => e.id), contains('ev-guest-cycle1'));
      expect(gEvents.any((e) => e.id == 'ev-alpha-cycle1'), isFalse);

      // Cycle 4: User Beta writes data
      final bDb1 = await coordinator.switchSession(const AuthenticatedDbAuthState('user-beta'));
      await bDb1.eventDao.insertEvent(
        CalendarEventsCompanion.insert(
          id: 'ev-beta-cycle1',
          userId: 'user-beta',
          title: 'Beta Event 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final bEvents = await bDb1.eventDao.watchAllEvents().first;
      expect(bEvents.map((e) => e.id), contains('ev-beta-cycle1'));
      expect(bEvents.any((e) => e.id == 'ev-alpha-cycle1'), isFalse);
      expect(bEvents.any((e) => e.id == 'ev-guest-cycle1'), isFalse);

      // Cycle 5: User Alpha reconnects and confirms only Alpha data is present
      final aDb2 = await coordinator.switchSession(const AuthenticatedDbAuthState('user-alpha'));
      final aEvents = await aDb2.eventDao.watchAllEvents().first;
      expect(aEvents.map((e) => e.id), contains('ev-alpha-cycle1'));
      expect(aEvents.any((e) => e.id == 'ev-beta-cycle1'), isFalse);
      expect(aEvents.any((e) => e.id == 'ev-guest-cycle1'), isFalse);
    });
  });

  group('Adversarial Stress Suite 3: Post-Severing Query Rejections', () {
    test('Every type of read, write, and custom query on severed handles immediately fails post-sever', () async {
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

      // 1. Establish session as Charlie
      const charlieId = 'user-charlie-sever-target';
      final charlieDb = await coordinator.switchSession(const AuthenticatedDbAuthState(charlieId));
      final now = DateTime.now();

      await charlieDb.spaceDao.insertSpace(
        CalendarSpacesCompanion.insert(
          id: 'sp-charlie-init',
          userId: charlieId,
          name: 'Charlie Space',
          type: 'personal',
          color: 0xFF112233,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify charlieDb works initially
      final initialSpaces = await charlieDb.spaceDao.watchAllSpaces().first;
      expect(initialSpaces.length, equals(1));

      // 2. Sever connection and switch to Guest
      final guestDb = await coordinator.severAndSwitchToGuest();
      expect(identical(charlieDb, guestDb), isFalse);

      // 3. Stress-test all operation types on charlieDb (must ALL throw):
      // A. Stream query read
      expect(
        () async => await charlieDb.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Stream query on severed handle must fail',
      );

      // B. Select get() read
      expect(
        () async => await charlieDb.select(charlieDb.calendarSpaces).get(),
        throwsA(anything),
        reason: 'Direct select on severed handle must fail',
      );

      // C. Insert write
      expect(
        () async => await charlieDb.spaceDao.insertSpace(
          CalendarSpacesCompanion.insert(
            id: 'sp-charlie-rogue',
            userId: charlieId,
            name: 'Rogue Insert',
            type: 'personal',
            color: 0xFF000000,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
        reason: 'Insert on severed handle must fail',
      );

      // D. Custom SQL query execution
      expect(
        () async => await charlieDb.customSelect('SELECT 1').get(),
        throwsA(anything),
        reason: 'Custom SQL query on severed handle must fail',
      );

      // 4. Switching from Guest to new user also severs previous Guest handle
      final guestHandleBeforeLogin = guestDb;
      final daveDb = await coordinator.switchSession(const AuthenticatedDbAuthState('user-dave'));

      expect(
        () async => await guestHandleBeforeLogin.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Guest handle must also be severed when switching to authenticated user',
      );

      // daveDb is functional
      final daveSpaces = await daveDb.spaceDao.watchAllSpaces().first;
      expect(daveSpaces.isEmpty, isTrue);
    });
  });

  group('Adversarial Stress Suite 4: Multi-Device Remote Kickout & Token Severing', () {
    test('Targeted remote kickout severs target device database and erases secure tokens while preserving non-target devices', () async {
      final inMemoryDbFactory = InMemoryDatabaseConnectionFactory();
      final inMemoryStorageDeviceA = InMemorySecureStorageService();
      final inMemoryStorageDeviceB = InMemorySecureStorageService();
      final mockRealtime = MockSessionRealtimeDataSource();

      // Configure Device A
      final containerA = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorageDeviceA),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );
      addTearDown(containerA.dispose);

      // Configure Device B
      final containerB = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorageDeviceB),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );
      addTearDown(containerB.dispose);
      addTearDown(mockRealtime.dispose);

      final notifierA = containerA.read(authNotifierProvider.notifier);
      final notifierB = containerB.read(authNotifierProvider.notifier);
      await notifierA.init();
      await notifierB.init();

      // Both devices log in with user credentials
      const userEmail = 'victor@chronohub.com';
      const userPass = 'pass123456';
      await notifierA.signInWithEmail(userEmail, userPass);
      await notifierB.signInWithEmail(userEmail, userPass);

      expect(containerA.read(authNotifierProvider), isA<Authenticated>());
      expect(containerB.read(authNotifierProvider), isA<Authenticated>());

      final userA = (containerA.read(authNotifierProvider) as Authenticated).user;
      final deviceIdA = await containerA.read(sessionRegistryRepositoryProvider).getCurrentDeviceId();
      final deviceIdB = await containerB.read(sessionRegistryRepositoryProvider).getCurrentDeviceId();
      expect(deviceIdA, isNot(equals(deviceIdB)));

      // Retain active database handle on Device B before kickout
      final coordinatorB = containerB.read(databaseLifecycleCoordinatorProvider);
      final preKickDbB = coordinatorB.activeDatabase;

      // Device A issues targeted kickout against Device B
      final sessionRepoA = containerA.read(sessionRegistryRepositoryProvider);
      await sessionRepoA.kickDevice(deviceId: deviceIdB, userId: userA.id);

      // Wait for event broadcast and async state transitions
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Device B must transition to AuthUnauthenticated
      final stateB = containerB.read(authNotifierProvider);
      expect(stateB, isA<AuthUnauthenticated>());
      expect((stateB as AuthUnauthenticated).reason, contains('Session terminated by another device'));

      // Device B's auth tokens must be wiped from secure storage
      final authLocalB = AuthLocalDataSource(inMemoryStorageDeviceB);
      expect(await authLocalB.getSession(), isNull);

      // Device B's pre-kick database handle must be severed and throw on query
      expect(
        () async => await preKickDbB.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Pre-kick database handle on Device B must be severed',
      );

      // Device B's active coordinator database is restored to guest.db
      final activeDbStateB = containerB.read(currentAuthForDbProvider);
      expect(activeDbStateB, isA<GuestDbAuthState>());
      expect(HashUtils.resolveDatabaseName(activeDbStateB.userId), equals('guest.db'));

      // Device A must remain fully authenticated and intact
      final stateA = containerA.read(authNotifierProvider);
      expect(stateA, isA<Authenticated>());
      final activeDbStateA = containerA.read(currentAuthForDbProvider);
      expect(activeDbStateA, isA<AuthenticatedDbAuthState>());
      expect(await AuthLocalDataSource(inMemoryStorageDeviceA).getSession(), isNotNull);
    });

    test('kickAllOtherDevices kicks every secondary device while preserving the initiator session', () async {
      final inMemoryDbFactory = InMemoryDatabaseConnectionFactory();
      final storageInitiator = InMemorySecureStorageService();
      final storageVictim1 = InMemorySecureStorageService();
      final storageVictim2 = InMemorySecureStorageService();
      final mockRealtime = MockSessionRealtimeDataSource();

      final cInitiator = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(storageInitiator),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );
      final cVictim1 = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(storageVictim1),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );
      final cVictim2 = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(storageVictim2),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );

      addTearDown(cInitiator.dispose);
      addTearDown(cVictim1.dispose);
      addTearDown(cVictim2.dispose);
      addTearDown(mockRealtime.dispose);

      final nInitiator = cInitiator.read(authNotifierProvider.notifier);
      final nVictim1 = cVictim1.read(authNotifierProvider.notifier);
      final nVictim2 = cVictim2.read(authNotifierProvider.notifier);

      await nInitiator.init();
      await nVictim1.init();
      await nVictim2.init();

      const userEmail = 'multi@chronohub.com';
      const userPass = 'pass123456';
      await nInitiator.signInWithEmail(userEmail, userPass);
      await nVictim1.signInWithEmail(userEmail, userPass);
      await nVictim2.signInWithEmail(userEmail, userPass);

      final user = (cInitiator.read(authNotifierProvider) as Authenticated).user;
      final devInit = await cInitiator.read(sessionRegistryRepositoryProvider).getCurrentDeviceId();

      // Pre-kick handles for victims
      final preKickDb1 = cVictim1.read(databaseLifecycleCoordinatorProvider).activeDatabase;
      final preKickDb2 = cVictim2.read(databaseLifecycleCoordinatorProvider).activeDatabase;

      // Initiator triggers kickAllOtherDevices
      await cInitiator.read(sessionRegistryRepositoryProvider).kickAllOtherDevices(
        currentDeviceId: devInit,
        userId: user.id,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Initiator remains authenticated
      expect(cInitiator.read(authNotifierProvider), isA<Authenticated>());
      expect(await AuthLocalDataSource(storageInitiator).getSession(), isNotNull);

      // Victim 1 & Victim 2 must both be unauthenticated and severed
      expect(cVictim1.read(authNotifierProvider), isA<AuthUnauthenticated>());
      expect(cVictim2.read(authNotifierProvider), isA<AuthUnauthenticated>());

      expect(await AuthLocalDataSource(storageVictim1).getSession(), isNull);
      expect(await AuthLocalDataSource(storageVictim2).getSession(), isNull);

      expect(
        () async => await preKickDb1.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Victim 1 DB handle must be severed',
      );
      expect(
        () async => await preKickDb2.spaceDao.watchAllSpaces().first,
        throwsA(anything),
        reason: 'Victim 2 DB handle must be severed',
      );
    });

    test('Remote kickout broadcast for a different userId has zero effect on current session', () async {
      final inMemoryDbFactory = InMemoryDatabaseConnectionFactory();
      final inMemoryStorage = InMemorySecureStorageService();
      final mockRealtime = MockSessionRealtimeDataSource();

      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(inMemoryDbFactory),
          secureStorageServiceProvider.overrideWithValue(inMemoryStorage),
          sessionRealtimeDataSourceProvider.overrideWithValue(mockRealtime),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockRealtime.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.init();
      await notifier.signInWithEmail('legit@chronohub.com', 'password123');

      final authState = container.read(authNotifierProvider);
      expect(authState, isA<Authenticated>());

      // Broadcast kickout targeted at a different user ID
      mockRealtime.simulateRemoteKick(
        KickoutEvent(
          userId: 'completely-different-user-999',
          targetDeviceId: null,
          excludedDeviceId: null,
          reason: 'Other user logged out',
          timestamp: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Current session must remain authenticated
      expect(container.read(authNotifierProvider), isA<Authenticated>());
      expect(await AuthLocalDataSource(inMemoryStorage).getSession(), isNotNull);
    });
  });
}
