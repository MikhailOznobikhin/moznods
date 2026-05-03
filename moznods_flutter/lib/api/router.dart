import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/auth_provider.dart';
import '../ui/screens/dashboard_layout.dart';
import '../ui/screens/discovery_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/register_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!isLoggedIn && !isLoggingIn && !isRegistering) return '/login';
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
    ],
  );
});
