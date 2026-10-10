import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/errors/failures.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_session.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_state.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/auth_user.dart';
import 'package:smart_calendar_hub/features/auth/domain/entities/kickout_event.dart';

void main() {
  group('Auth Domain Entities & State Machine Tests', () {
    test('AuthUser guest factory initializes guest properties correctly', () {
      final guest = AuthUser.guest();
      expect(guest.isGuest, isTrue);
      expect(guest.id, equals('guest'));
      expect(guest.email, isNull);
      expect(guest.displayName, equals('Guest User'));
    });

    test('AuthUser authenticated factory initializes user correctly', () {
      final user = AuthUser.authenticated(
        id: 'u-123',
        email: 'alice@example.com',
        displayName: 'Alice',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(user.isGuest, isFalse);
      expect(user.id, equals('u-123'));
      expect(user.email, equals('alice@example.com'));
      expect(user.displayName, equals('Alice'));
    });

    test('AuthSession expiration and refresh threshold checks', () {
      final now = DateTime.now();
      final expiredSession = AuthSession(
        accessToken: 'expired_access',
        refreshToken: 'expired_refresh',
        expiresAt: now.subtract(const Duration(seconds: 10)),
        user: AuthUser.guest(),
      );
      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.needsRefresh, isFalse);

      final urgentSession = AuthSession(
        accessToken: 'urgent_access',
        refreshToken: 'urgent_refresh',
        expiresAt: now.add(const Duration(minutes: 3)),
        user: AuthUser.guest(),
      );
      expect(urgentSession.isExpired, isFalse);
      expect(urgentSession.needsRefresh, isTrue);

      final validSession = AuthSession(
        accessToken: 'valid_access',
        refreshToken: 'valid_refresh',
        expiresAt: now.add(const Duration(hours: 2)),
        user: AuthUser.guest(),
      );
      expect(validSession.isExpired, isFalse);
      expect(validSession.needsRefresh, isFalse);
    });

    test('AuthState sealed pattern exhaustiveness', () {
      final states = <AuthState>[
        const AuthInitial(),
        const AuthLoading(message: 'Testing...'),
        AuthGuest(AuthUser.guest()),
        Authenticated(
          user: AuthUser.guest(),
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            user: AuthUser.guest(),
          ),
        ),
        const AuthUnauthenticated(reason: 'Logged out'),
        const AuthError(AuthFailure('Invalid password')),
        AuthMigrationRequired(
          user: AuthUser.guest(),
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            user: AuthUser.guest(),
          ),
          localGuestEventCount: 3,
          cloudEventCount: 5,
        ),
      ];

      for (final state in states) {
        final description = switch (state) {
          AuthInitial() => 'initial',
          AuthLoading(:final message) => 'loading: $message',
          AuthGuest(:final guestUser) => 'guest: ${guestUser.id}',
          Authenticated(:final user) => 'auth: ${user.id}',
          AuthUnauthenticated(:final reason) => 'unauth: $reason',
          AuthError(:final failure) => 'error: ${failure.message}',
          AuthMigrationRequired(:final localGuestEventCount) =>
            'migration: $localGuestEventCount',
        };
        expect(description, isNotEmpty);
      }
    });

    test('KickoutEvent matchesDevice logic', () {
      final specificKick = KickoutEvent(
        userId: 'u-1',
        targetDeviceId: 'device-target-99',
        reason: 'Revoked',
        timestamp: DateTime.now(),
      );
      expect(specificKick.matchesDevice('device-target-99'), isTrue);
      expect(specificKick.matchesDevice('device-target-00'), isFalse);

      final kickAllExcept = KickoutEvent(
        userId: 'u-1',
        targetDeviceId: null,
        excludedDeviceId: 'device-my-current',
        reason: 'Revoked all others',
        timestamp: DateTime.now(),
      );
      expect(kickAllExcept.matchesDevice('device-my-current'), isFalse);
      expect(kickAllExcept.matchesDevice('device-other-1'), isTrue);
      expect(kickAllExcept.matchesDevice('device-other-2'), isTrue);
    });
  });
}
