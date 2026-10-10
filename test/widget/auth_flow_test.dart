import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/database/app_database_provider.dart';
import 'package:smart_calendar_hub/core/database/connection/in_memory_database_connection_factory.dart';
import 'package:smart_calendar_hub/core/database/migrations/migration_models.dart';
import 'package:smart_calendar_hub/core/platform/platform_providers.dart';
import 'package:smart_calendar_hub/core/platform/secure_storage_service.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/user_device.dart';
import 'package:smart_calendar_hub/features/auth/presentation/dialogs/conflict_resolution_dialog.dart';
import 'package:smart_calendar_hub/features/auth/presentation/screens/auth_portal_screen.dart';
import 'package:smart_calendar_hub/features/auth/presentation/widgets/device_card.dart';
import 'package:smart_calendar_hub/features/auth/presentation/widgets/guest_mode_banner.dart';

import 'package:go_router/go_router.dart';
import 'package:smart_calendar_hub/app/router.dart';
import 'package:smart_calendar_hub/core/constants/route_constants.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_session.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_state.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_user.dart';
import 'package:smart_calendar_hub/features/auth/presentation/providers/auth_providers.dart';
import 'package:smart_calendar_hub/features/auth/presentation/screens/magic_link_sent_screen.dart';

void main() {
  Widget createTestWidget(Widget child, [ProviderContainer? container]) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => child,
        ),
        GoRoute(
          path: RouteConstants.guest,
          builder: (context, state) => const Scaffold(body: Text('Guest Canvas')),
        ),
        GoRoute(
          path: RouteConstants.calendar,
          builder: (context, state) => const Scaffold(body: Text('Calendar Canvas')),
        ),
        GoRoute(
          path: RouteConstants.passwordReset,
          builder: (context, state) => const Scaffold(body: Text('Password Reset')),
        ),
        GoRoute(
          path: RouteConstants.magicLinkSent,
          builder: (context, state) => const Scaffold(body: Text('Magic Link Sent')),
        ),
      ],
    );

    final app = MaterialApp.router(
      routerConfig: router,
    );

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: app,
      );
    }
    return ProviderScope(
      overrides: [
        databaseConnectionFactoryProvider.overrideWithValue(InMemoryDatabaseConnectionFactory()),
        secureStorageServiceProvider.overrideWithValue(InMemorySecureStorageService()),
      ],
      child: app,
    );
  }

  group('Widget Test Suite 1: GuestModeBanner Tests', () {
    testWidgets('GuestModeBanner displays informative banner and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestWidget(
          GuestModeBanner(
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.textContaining('訪客離線模式'), findsOneWidget);
      expect(find.text('立即登入'), findsOneWidget);

      await tester.tap(find.text('立即登入'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('Widget Test Suite 2: AuthPortalScreen UI Tests', () {
    testWidgets('AuthPortalScreen renders tabs and allows switching', (tester) async {
      await tester.pumpWidget(createTestWidget(const AuthPortalScreen()));
      await tester.pump();

      expect(find.text('ChronoHub'), findsOneWidget);
      expect(find.text('登入'), findsOneWidget);
      expect(find.text('註冊'), findsOneWidget);
      expect(find.text('免密碼'), findsOneWidget);
      expect(find.text('先不登入，直接以訪客模式體驗'), findsOneWidget);

      // Verify Sign In fields are present
      expect(find.text('登入帳號'), findsOneWidget);

      // Switch to Sign Up tab
      await tester.tap(find.text('註冊'));
      await tester.pumpAndSettle();
      expect(find.text('建立新帳號'), findsOneWidget);

      // Switch to Magic Link tab
      await tester.tap(find.text('免密碼'));
      await tester.pumpAndSettle();
      expect(find.text('發送免密碼連結'), findsOneWidget);
    });
  });

  group('Widget Test Suite 3: ConflictResolutionDialog Tests', () {
    testWidgets('Tapping Merge Local option returns MigrationMode.mergeLocal', (tester) async {
      MigrationMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedMode = await ConflictResolutionDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('帳號資料衝突裁決'), findsOneWidget);
      expect(find.text('合併本地行程至個人日曆'), findsOneWidget);
      expect(find.text('放棄本地草稿，以雲端為主'), findsOneWidget);

      // Tap Merge Local
      await tester.tap(find.text('合併本地行程至個人日曆'));
      await tester.pumpAndSettle();

      expect(selectedMode, equals(MigrationMode.mergeLocal));
    });

    testWidgets('Tapping Discard Local option returns MigrationMode.discardLocal', (tester) async {
      MigrationMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedMode = await ConflictResolutionDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap Discard Local
      await tester.tap(find.text('放棄本地草稿，以雲端為主'));
      await tester.pumpAndSettle();

      expect(selectedMode, equals(MigrationMode.discardLocal));
    });

    testWidgets('Tapping Cancel returns null', (tester) async {
      MigrationMode? selectedMode = MigrationMode.autoMigrate;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedMode = await ConflictResolutionDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('取消並返回訪客模式'));
      await tester.pumpAndSettle();

      expect(selectedMode, isNull);
    });
  });

  group('Widget Test Suite 4: DeviceCard UI Tests', () {
    testWidgets('DeviceCard renders device attributes and triggers kick callback', (tester) async {
      bool kicked = false;
      final device = UserDevice(
        id: 'remote-test-device-id',
        userId: 'user-123',
        deviceName: 'Workstation ThinkPad (Windows)',
        platform: 'windows',
        deviceToken: 'tok_123',
        lastActiveAt: DateTime.now().subtract(const Duration(minutes: 5)),
        clientIp: '192.168.1.100',
        isCurrent: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onKick: () => kicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Workstation ThinkPad (Windows)'), findsOneWidget);
      expect(find.textContaining('平台: WINDOWS'), findsOneWidget);
      expect(find.text('IP: 192.168.1.100'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pump();

      expect(kicked, isTrue);
    });

    testWidgets('DeviceCard displays "本設備" badge when isCurrent is true and hides kick button', (tester) async {
      final currentDevice = UserDevice(
        id: 'current-device-id',
        userId: 'user-123',
        deviceName: 'My MacBook Pro (macOS)',
        platform: 'macos',
        deviceToken: 'tok_curr',
        lastActiveAt: DateTime.now(),
        clientIp: '10.0.0.5',
        isCurrent: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(device: currentDevice),
          ),
        ),
      );

      expect(find.text('本設備'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
    });
  });

  group('Widget Test Suite 5: Post-Auth Navigation & Redirect Guard Tests', () {
    testWidgets('authRedirectGuard redirects authenticated user away from restricted routes', (tester) async {
      final fakeSession = AuthSession(
        accessToken: 'valid_tok',
        refreshToken: 'valid_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: AuthUser.authenticated(
          id: 'u-guard-1',
          email: 'guard@example.com',
          displayName: 'Guard User',
          createdAt: DateTime.now(),
        ),
      );
      final authenticatedState = Authenticated(user: fakeSession.user, session: fakeSession);
      const unauthenticatedState = AuthUnauthenticated();

      // Verify unauthenticated user is NOT redirected from login or guest
      final unauthLoginRedirect = evaluateAuthRedirect(RouteConstants.login, unauthenticatedState);
      expect(unauthLoginRedirect, isNull);

      final unauthGuestRedirect = evaluateAuthRedirect(RouteConstants.guest, unauthenticatedState);
      expect(unauthGuestRedirect, isNull);

      // Verify authenticated user IS redirected to /calendar from /login
      final authLoginRedirect = evaluateAuthRedirect(RouteConstants.login, authenticatedState);
      expect(authLoginRedirect, equals(RouteConstants.calendar));

      // Verify authenticated user IS redirected to /calendar from /guest
      final authGuestRedirect = evaluateAuthRedirect(RouteConstants.guest, authenticatedState);
      expect(authGuestRedirect, equals(RouteConstants.calendar));

      // Verify authenticated user IS redirected to /calendar from /magic-link-sent
      final authMagicRedirect = evaluateAuthRedirect(RouteConstants.magicLinkSent, authenticatedState);
      expect(authMagicRedirect, equals(RouteConstants.calendar));
    });

    testWidgets('AuthPortalScreen navigates to /calendar on Authenticated state transition', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(InMemoryDatabaseConnectionFactory()),
          secureStorageServiceProvider.overrideWithValue(InMemorySecureStorageService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestWidget(const AuthPortalScreen(), container));
      await tester.pump();

      expect(find.text('登入帳號'), findsOneWidget);

      // Emit Authenticated state
      final fakeSession = AuthSession(
        accessToken: 'tok_nav',
        refreshToken: 'ref_nav',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: AuthUser.authenticated(
          id: 'u-portal-nav',
          email: 'nav@example.com',
          displayName: 'Nav Tester',
          createdAt: DateTime.now(),
        ),
      );
      container.read(authNotifierProvider.notifier).state = Authenticated(
        user: fakeSession.user,
        session: fakeSession,
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar Canvas'), findsOneWidget);
    });

    testWidgets('MagicLinkSentScreen navigates to /calendar on Authenticated state transition', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseConnectionFactoryProvider.overrideWithValue(InMemoryDatabaseConnectionFactory()),
          secureStorageServiceProvider.overrideWithValue(InMemorySecureStorageService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createTestWidget(
          const MagicLinkSentScreen(email: 'test@example.com'),
          container,
        ),
      );
      await tester.pump();

      expect(find.text('已發送驗證郵件'), findsOneWidget);

      // Emit Authenticated state
      final fakeSession = AuthSession(
        accessToken: 'tok_magic_nav',
        refreshToken: 'ref_magic_nav',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: AuthUser.authenticated(
          id: 'u-magic-nav',
          email: 'test@example.com',
          displayName: 'Magic Tester',
          createdAt: DateTime.now(),
        ),
      );
      container.read(authNotifierProvider.notifier).state = Authenticated(
        user: fakeSession.user,
        session: fakeSession,
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar Canvas'), findsOneWidget);
    });
  });
}
