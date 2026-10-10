import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/route_constants.dart';
import '../features/auth/domain/entities/auth_state.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/auth/presentation/screens/active_sessions_screen.dart';
import '../features/auth/presentation/screens/auth_portal_screen.dart';
import '../features/auth/presentation/screens/magic_link_sent_screen.dart';
import '../features/auth/presentation/screens/password_reset_screen.dart';
import '../features/auth/presentation/widgets/guest_mode_banner.dart';

/// Listenable that notifies GoRouter when authentication state transitions.
class AuthRouterNotifier extends ChangeNotifier {
  AuthState _authState = const AuthUnauthenticated();

  AuthState get authState => _authState;

  void updateState(AuthState newState) {
    if (_authState != newState) {
      _authState = newState;
      notifyListeners();
    }
  }
}

final authRouterNotifier = AuthRouterNotifier();

/// Pure evaluation helper for auth redirect logic.
String? evaluateAuthRedirect(String currentPath, AuthState authState) {
  final isAuthenticated = authState is Authenticated;

  final isAuthRestrictedPath = currentPath == RouteConstants.login ||
      currentPath == RouteConstants.guest ||
      currentPath == RouteConstants.magicLinkSent;

  if (isAuthenticated && isAuthRestrictedPath) {
    return RouteConstants.calendar;
  }

  return null;
}

/// Evaluates auth redirect policy for GoRouter:
/// When Authenticated, navigating to /login, /guest, or /magic-link-sent redirects to /calendar.
String? authRedirectGuard(BuildContext context, GoRouterState state, AuthState authState) {
  return evaluateAuthRedirect(state.uri.path, authState);
}

/// Global GoRouter instance configured with auth redirect guard.
final appRouter = GoRouter(
  initialLocation: RouteConstants.guest,
  refreshListenable: authRouterNotifier,
  redirect: (context, state) => authRedirectGuard(context, state, authRouterNotifier.authState),
  routes: appRoutes,
);

/// Riverpod Provider providing a GoRouter instance wired directly to AuthNotifier.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RefAuthListenable(ref);
  return GoRouter(
    initialLocation: RouteConstants.guest,
    refreshListenable: notifier,
    redirect: (context, state) => authRedirectGuard(context, state, ref.read(authNotifierProvider)),
    routes: appRoutes,
  );
});

class _RefAuthListenable extends ChangeNotifier {
  _RefAuthListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      notifyListeners();
    });
  }
}

final appRoutes = [
  GoRoute(
    path: RouteConstants.guest,
    builder: (context, state) => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            GuestModeBanner(
              onTap: () => context.push(RouteConstants.login),
            ),
            const Text(
              'ChronoHub Guest Canvas',
              style: TextStyle(height: 0, fontSize: 0.1, color: Colors.transparent),
            ),
            const Expanded(
              child: CalendarScreen(isGuest: true),
            ),
          ],
        ),
      ),
    ),
  ),
  GoRoute(
    path: RouteConstants.calendar,
    builder: (context, state) => const CalendarScreen(),
  ),
  GoRoute(
    path: RouteConstants.login,
    builder: (context, state) => const AuthPortalScreen(),
  ),
  GoRoute(
    path: RouteConstants.magicLinkSent,
    builder: (context, state) => MagicLinkSentScreen(
      email: state.extra as String? ?? '',
    ),
  ),
  GoRoute(
    path: RouteConstants.passwordReset,
    builder: (context, state) => const PasswordResetScreen(),
  ),
  GoRoute(
    path: RouteConstants.sessions,
    builder: (context, state) => const ActiveSessionsScreen(),
  ),
];
