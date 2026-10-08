import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/auth_provider.dart';
import '../ui/screens/call_screen.dart';
import '../ui/screens/dashboard_layout.dart';
import '../ui/screens/discovery_screen.dart';
import '../ui/screens/download_screen.dart';
import '../ui/screens/edit_profile_screen.dart';
import '../ui/screens/invite_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/register_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/screens/user_profile_screen.dart';

const _publicPaths = {'/login', '/register', '/download'};

/// Re-runs GoRouter redirects when auth changes, without rebuilding the router
/// (rebuilding it reset navigation and dropped deep links).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id ||
          previous?.initialized != next.initialized) {
        notifyListeners();
      }
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final from = state.uri.queryParameters['from'];

      if (!auth.initialized) {
        if (path == '/splash') return null;
        return '/splash?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      final isLoggedIn = auth.user != null;
      if (path == '/splash') {
        final target = from ?? '/';
        if (!isLoggedIn && !_publicPaths.contains(Uri.parse(target).path)) {
          return target == '/' ? '/login' : '/login?from=${Uri.encodeComponent(target)}';
        }
        return target;
      }
      if (!isLoggedIn && !_publicPaths.contains(path)) {
        final target = state.uri.toString();
        return target == '/' ? '/login' : '/login?from=${Uri.encodeComponent(target)}';
      }
      if (isLoggedIn && (path == '/login' || path == '/register')) {
        return from ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardLayout(),
        routes: [
          GoRoute(
            path: 'discover',
            builder: (context, state) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: 'room/:roomId',
            builder: (context, state) {
              final roomId = int.tryParse(state.pathParameters['roomId'] ?? '');
              return DashboardLayout(initialRoomId: roomId);
            },
          ),
        ],
      ),
      GoRoute(path: '/call', builder: (context, state) => const CallScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          final userId = ref.read(authProvider).user?.id;
          if (userId == null) return const LoginScreen();
          return UserProfileScreen(userId: userId);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/download',
        builder: (context, state) => const DownloadScreen(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return InviteScreen(token: token);
        },
      ),
    ],
  );
});
