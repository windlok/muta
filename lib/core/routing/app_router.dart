import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../providers/providers.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/setup_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/planner/presentation/planner_screen.dart';
import '../../features/price_tracker/presentation/prices_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';

/// Oturum değişimlerini GoRouter'a bildirir; böylece giriş/çıkışta
/// yönlendirme kuralları yeniden çalışır.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(AuthRepository repo) {
    _sub = repo.onAuthStateChange.listen((state) {
      // Supabase may finish the PKCE code exchange just after the deep link
      // opens the existing Activity. Schedule the refresh after that event
      // has propagated through the auth client.
      Future<void>.delayed(const Duration(milliseconds: 150), notifyListeners);
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefreshNotifier(auth);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Önce kurulum kontrolü.
      if (!AppConfig.isSupabaseConfigured) {
        return location == '/setup' ? null : '/setup';
      }

      final loggedIn =
          ref.read(authRepositoryProvider).currentSession?.user != null;
      final isAuthRoute =
          location == '/login' ||
          location == '/register' ||
          location == '/setup';

      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TasksScreen()),
          GoRoute(path: '/prices', builder: (_, _) => const PricesScreen()),
          GoRoute(path: '/planner', builder: (_, _) => const PlannerScreen()),
        ],
      ),
    ],
  );
});
