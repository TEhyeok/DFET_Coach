import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_state.dart';
import '../screens/login_screen.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/users_list_page.dart';
import 'pages/user_detail_page.dart';
import 'pages/settings_page.dart';
import 'pages/analytics_page.dart';
import 'pages/requests_page.dart';
import 'pages/content/content_dashboard_page.dart';
import 'pages/content/workout_manager_page.dart';
import 'pages/content/food_manager_page.dart';
import 'pages/admin_management_page.dart';
import 'widgets/admin_layout.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/admin',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = ref.read(isLoggedInProvider);
      final isLoggingIn = state.uri.path == '/login';

      // 로그인되지 않았고 로그인 페이지가 아니면 로그인 페이지로
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 로그인되었고 로그인 페이지면 대시보드로
      if (isLoggedIn && isLoggingIn) {
        return '/admin';
      }

      // 관리자 승인 확인은 로그인 시에만 수행 (LoginScreen에서 처리)
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          String currentPage = 'dashboard';
          final location = state.uri.path;
          if (location.startsWith('/admin/users')) {
            currentPage = 'users';
          } else if (location.startsWith('/admin/analytics')) {
            currentPage = 'analytics';
          } else if (location.startsWith('/admin/settings')) {
            currentPage = 'settings';
          } else if (location.startsWith('/admin/requests')) {
            currentPage = 'requests';
          } else if (location.startsWith('/admin/content')) {
            currentPage = 'content';
          } else if (location.startsWith('/admin/admins')) {
            currentPage = 'admins';
          }
          return AdminLayout(
            key: ValueKey(currentPage),
            currentPage: currentPage,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const AdminDashboardPage(),
            ),
          ),
          GoRoute(
            path: '/admin/users',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const UsersListPage(),
            ),
            routes: [
              GoRoute(
                path: ':uid',
                pageBuilder: (context, state) {
                  final uid = state.pathParameters['uid']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  final userName = extra?['userName'] as String? ?? 'User';
                  return buildFadeTransitionPage(
                    context: context,
                    state: state,
                    child: UserDetailPage(uid: uid, userName: userName),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/admin/analytics',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const AnalyticsPage(),
            ),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const SettingsPage(),
            ),
          ),
          GoRoute(
            path: '/admin/requests',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const RequestsPage(),
            ),
          ),
          GoRoute(
            path: '/admin/content',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const ContentDashboardPage(),
            ),
            routes: [
              GoRoute(
                path: 'workouts',
                pageBuilder: (context, state) => buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: const WorkoutManagerPage(),
                ),
              ),
              GoRoute(
                path: 'foods',
                pageBuilder: (context, state) => buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: const FoodManagerPage(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/admins',
            pageBuilder: (context, state) => buildFadeTransitionPage(
              context: context,
              state: state,
              child: const AdminManagementPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/',
        redirect: (_, __) => '/admin',
      ),
    ],
  );
});

/// Helper function for consistent fade transitions
CustomTransitionPage buildFadeTransitionPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      );
    },
  );
}
