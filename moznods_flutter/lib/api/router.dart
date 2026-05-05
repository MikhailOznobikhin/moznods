import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/auth_provider.dart';
import '../ui/screens/dashboard_layout.dart';
import '../ui/screens/discovery_screen.dart';
import '../ui/screens/download_screen.dart';
import '../ui/screens/edit_profile_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/register_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/user_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final matchedLocation = state.matchedLocation;
      final pathLocation = state.uri.path;
      final fragmentLocation = '/${state.uri.fragment.replaceFirst(RegExp(r'^/+'), '')}';

      final isLoggingIn =
          matchedLocation == '/login' ||
          pathLocation == '/login' ||
          fragmentLocation == '/login';
      final isRegistering =
          matchedLocation == '/register' ||
          pathLocation == '/register' ||
          fragmentLocation == '/register';
      final isDownloadPage =
          matchedLocation == '/download' ||
          pathLocation == '/download' ||
          fragmentLocation == '/download';

      if (!isLoggedIn && !isLoggingIn && !isRegistering && !isDownloadPage) {
        return '/login';
      }
      if (isLoggedIn && (isLoggingIn || isRegistering)) return '/';
      return null;
    },
    routes: [
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
          final userId = authState.user?.id;
          if (userId == null) {
            return const LoginScreen();
          }
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
    ],
  );
});
