import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_bootstrap.dart';
import '../features/analytics/presentation/analytics_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/customers/presentation/customer_detail_page.dart';
import '../features/customers/presentation/customer_form_page.dart';
import '../features/customers/presentation/customers_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/export/presentation/export_page.dart';
import '../features/map/presentation/map_page.dart';
import '../features/reminders/presentation/reminders_page.dart';
import '../features/scanner/presentation/scanner_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/visits/presentation/visits_page.dart';
import '../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _SupabaseAuthRefresh();
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (_, state) {
      final authRoute = switch (state.uri.path) {
        '/login' || '/register' || '/forgot-password' => true,
        _ => false,
      };
      final signedIn = SupabaseBootstrap.configured &&
          SupabaseBootstrap.client.auth.currentSession != null;

      if (signedIn && authRoute && state.uri.path != '/login') {
        return '/dashboard';
      }
      if (SupabaseBootstrap.configured && !signedIn && !authRoute) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: '/customers',
            builder: (_, __) => const CustomersPage(),
          ),
          GoRoute(
            path: '/customers/new',
            builder: (_, __) => const CustomerFormPage(),
          ),
          GoRoute(
            path: '/customers/:id/edit',
            builder: (_, state) => CustomerFormPage(
              customerId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/customers/:id',
            builder: (_, state) =>
                CustomerDetailPage(customerId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/visits', builder: (_, __) => const VisitsPage()),
          GoRoute(path: '/scanner', builder: (_, __) => const ScannerPage()),
          GoRoute(path: '/map', builder: (_, __) => const MapPage()),
          GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const AnalyticsPage(),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, __) => const RemindersPage(),
          ),
          GoRoute(path: '/export', builder: (_, __) => const ExportPage()),
        ],
      ),
    ],
  );
});

class _SupabaseAuthRefresh extends ChangeNotifier {
  _SupabaseAuthRefresh() {
    if (!SupabaseBootstrap.configured) return;
    _subscription = SupabaseBootstrap.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
