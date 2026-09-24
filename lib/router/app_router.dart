import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/blood/blood_expert_screen.dart';
import '../screens/blood/blood_report_screen.dart';
import '../screens/blood/blood_screen.dart';
import '../screens/blood/blood_trends_screen.dart';
import '../screens/care_type_settings_screen.dart';
import '../screens/dashboard.dart';
import '../screens/insights/insight_detail_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/ios_profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/microbiome/microbiome_expert_screen.dart';
import '../screens/microbiome/microbiome_metric_screen.dart';
import '../screens/microbiome/microbiome_screen.dart';
import '../screens/notification_center_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/record_hub_screen.dart';
import '../screens/report_hub_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tickets.dart';
import '../state/app_state.dart';
import '../state/clinical_state.dart';
import '../theme/tokens.dart';
import '../widgets/shells/adaptive_home_shell.dart';
import '../widgets/shells/trainer_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final mobileRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final isTrainerGuest = ref.watch(isTrainerGuestModeProvider);
  final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);
  final profileAsync = ref.watch(userProfileProvider);
  final profile = profileAsync.valueOrNull;
  final featureFlags = ref.watch(featureFlagsProvider).valueOrNull;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isPublic = location == '/intro' || location == '/login';
      final isLoading = auth.isLoading ||
          (auth.valueOrNull != null && profileAsync.isLoading);

      if (isLoading) {
        return location == '/loading' ? null : '/loading';
      }
      if (!isLoggedIn) {
        final target = hasSeenOnboarding ? '/login' : '/intro';
        return location == target ? null : target;
      }
      if (isPublic || location == '/' || location == '/loading') {
        if (isTrainerGuest ||
            profile?.isTrainer == true ||
            profile?.isAdmin == true) {
          return '/trainer';
        }
        if (profile != null && !profile.isOnboardingComplete) {
          return '/profile-setup';
        }
        if (profile != null && profile.careTypeVersion == 0) {
          return '/onboarding/careType';
        }
        return '/home/dashboard';
      }

      final isExpertRoute = location.endsWith('/expert');
      final canViewExpert =
          profile?.isTrainer == true || profile?.isAdmin == true;
      if (isExpertRoute && !canViewExpert) return '/home/report';

      if (featureFlags != null) {
        final isGutRoute =
            location == '/home/gut' || location.startsWith('/gut/');
        final isBloodRoute =
            location == '/home/blood' || location.startsWith('/blood/');
        final isInsightRoute =
            location == '/home/insights' || location.startsWith('/insights/');
        if ((isGutRoute && !featureFlags.gut) ||
            (isBloodRoute && !featureFlags.blood) ||
            (isInsightRoute && !featureFlags.insights)) {
          return '/home/report';
        }
      }

      if (profile != null &&
          !profile.isOnboardingComplete &&
          location != '/profile-setup') {
        return '/profile-setup';
      }
      if (profile != null &&
          profile.careTypeVersion == 0 &&
          location != '/onboarding/careType') {
        return '/onboarding/careType';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _LoadingScreen()),
      GoRoute(path: '/loading', builder: (_, __) => const _LoadingScreen()),
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/trainer',
        builder: (_, __) => const TrainerShell(autoOpenNativeHome: true),
      ),
      GoRoute(
        path: '/onboarding/careType',
        builder: (_, __) => const _DetailScaffold(
          title: '케어 유형 확인',
          child: CareTypeSettingsScreen(requiredConfirmation: true),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            AdaptiveHomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/dashboard',
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/record',
                builder: (_, __) => const RecordHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/report',
                builder: (_, __) => const ReportHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/myPage',
                builder: (_, __) => const IOSProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/myPage/careType',
        builder: (_, __) => const _DetailScaffold(
          title: '케어 유형',
          child: CareTypeSettingsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/myPage/settings/theme',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/myPage/requests',
        builder: (_, __) => const _DetailScaffold(
          title: '코칭 요청',
          child: TicketsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/notifications',
        builder: (_, __) => const NotificationCenterPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/gut',
        builder: (_, __) => const _DetailScaffold(
          title: '장 건강',
          child: MicrobiomeScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/gut/:reportId',
        builder: (_, state) => _DetailScaffold(
          title: '장 건강 리포트',
          child: MicrobiomeScreen(
            reportId: state.pathParameters['reportId'],
          ),
        ),
        routes: [
          for (final metric in ['alpha', 'beta', 'composition', 'unifrac'])
            GoRoute(
              path: metric,
              builder: (_, state) => MicrobiomeMetricScreen(
                reportId: state.pathParameters['reportId']!,
                section: MicrobiomeMetricSection.values.byName(metric),
              ),
            ),
          GoRoute(
            path: 'expert',
            builder: (_, state) => MicrobiomeExpertScreen(
              reportId: state.pathParameters['reportId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/blood',
        builder: (_, __) => const _DetailScaffold(
          title: '혈액 POCT',
          child: BloodScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/blood/trends',
        builder: (_, __) => const _DetailScaffold(
          title: '혈액 검사 추이',
          child: BloodTrendsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/blood/:reportId',
        builder: (_, state) => _DetailScaffold(
          title: '혈액 검사 리포트',
          child: BloodReportScreen(
            reportId: state.pathParameters['reportId']!,
          ),
        ),
        routes: [
          for (final panel in ['liver', 'kidney', 'metabolic', 'lipid'])
            GoRoute(
              path: panel,
              builder: (_, state) => _DetailScaffold(
                title: '혈액 패널 상세',
                child: BloodReportScreen(
                  reportId: state.pathParameters['reportId']!,
                  panel: panel,
                ),
              ),
            ),
          GoRoute(
            path: 'expert',
            builder: (_, state) => _DetailScaffold(
              title: '혈액 전문가 상세',
              child: BloodExpertScreen(
                reportId: state.pathParameters['reportId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/home/insights',
        builder: (_, __) => const _DetailScaffold(
          title: '통합 인사이트',
          child: InsightsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/insights/:snapshotId',
        builder: (_, state) => _DetailScaffold(
          title: '통합 건강 상세',
          child: InsightDetailScreen(
            snapshotId: state.pathParameters['snapshotId']!,
          ),
        ),
      ),
    ],
  );
});

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}
