import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_system/d_fet_axis_glyph.dart';
import '../design_system/d_fet_axis_icon.dart';
import '../screens/blood/blood_expert_screen.dart';
import '../screens/blood/blood_report_screen.dart';
import '../screens/blood/blood_screen.dart';
import '../screens/blood/blood_trends_screen.dart';
import '../screens/care_type_settings_screen.dart';
import '../screens/dashboard/today_signal_screen.dart';
import '../screens/insights/insight_detail_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/microbiome/microbiome_expert_screen.dart';
import '../screens/microbiome/microbiome_metric_screen.dart';
import '../screens/microbiome/microbiome_screen.dart';
import '../screens/report_hub_screen.dart';
import '../screens/settings_screen.dart';
import '../services/clinical_repository.dart';
import '../state/clinical_state.dart';
import '../state/theme_provider.dart';
import '../state/user_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/clinical/gut_health_summary_card.dart';
import 'clinical_demo_data.dart';
import 'design_lab_atoms_screen.dart';

const clinicalDemoMode = bool.fromEnvironment(
  'DFET_CLINICAL_DEMO',
  defaultValue: false,
);

List<Override> get clinicalDemoOverrides => [
      userProfileProvider.overrideWith((ref) async => clinicalDemoProfile),
      featureFlagsProvider.overrideWith(
        (ref) => Stream.value(const AppFeatureFlags.enabled()),
      ),
      gutReportsProvider.overrideWith(
        (ref) => Stream.value(clinicalDemoGutReports),
      ),
      bloodReportsProvider.overrideWith(
        (ref) => Stream.value(clinicalDemoBloodReports),
      ),
      healthSnapshotsProvider.overrideWith(
        (ref) => Stream.value(clinicalDemoSnapshots),
      ),
      for (final report in clinicalDemoGutReports)
        gutReportProvider(report.reportId).overrideWith(
          (ref) => Stream.value(report),
        ),
      gutExpertReportProvider(clinicalDemoGutReports.first.reportId)
          .overrideWith(
        (ref) => Stream.value(clinicalDemoGutExpert),
      ),
      for (final report in clinicalDemoBloodReports)
        bloodReportProvider(report.reportId).overrideWith(
          (ref) => Stream.value(report),
        ),
      bloodExpertReportProvider(clinicalDemoBloodReports.first.reportId)
          .overrideWith(
        (ref) => Stream.value(clinicalDemoBloodExpert),
      ),
      for (final snapshot in clinicalDemoSnapshots)
        healthSnapshotProvider(snapshot.snapshotId).overrideWith(
          (ref) => Stream.value(snapshot),
        ),
      healthSnapshotProvider(clinicalDemoPartialSnapshot.snapshotId)
          .overrideWith(
        (ref) => Stream.value(clinicalDemoPartialSnapshot),
      ),
    ];

class ClinicalDemoApp extends ConsumerStatefulWidget {
  const ClinicalDemoApp({super.key});

  @override
  ConsumerState<ClinicalDemoApp> createState() => _ClinicalDemoAppState();
}

class _ClinicalDemoAppState extends ConsumerState<ClinicalDemoApp> {
  late final GoRouter _router = _buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'D-FET 통합 케어 데모',
      theme: appThemeLight(),
      darkTheme: appThemeDark(),
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/demo/overview',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            _ClinicalDemoShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/demo/overview',
                builder: (_, __) => const _ClinicalDemoOverview(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/demo/gut',
                builder: (_, __) => const MicrobiomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/demo/blood',
                builder: (_, __) => const BloodScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/demo/insights',
                builder: (_, __) => const InsightsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/demo/design-lab/atoms',
        builder: (_, __) => const DesignLabAtomsScreen(),
      ),
      GoRoute(
        path: '/demo/care-type',
        builder: (_, __) => _detailScaffold(
          title: '케어 유형 선택',
          child: const CareTypeSettingsScreen(requiredConfirmation: true),
        ),
      ),
      GoRoute(
        path: '/demo/report-hub',
        builder: (_, __) => _detailScaffold(
          title: '리포트',
          child: const ReportHubScreen(),
        ),
      ),
      GoRoute(
        path: '/demo/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/demo/dashboard-summary',
        builder: (_, __) => _detailScaffold(
          title: '홈 대시보드',
          child: const _GutSummaryEvidenceScreen(),
        ),
      ),
      GoRoute(
        path: '/demo/gut-empty',
        builder: (_, __) => ProviderScope(
          overrides: [
            gutReportsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: _detailScaffold(
            title: '장 건강',
            child: const MicrobiomeScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/demo/blood-empty',
        builder: (_, __) => ProviderScope(
          overrides: [
            bloodReportsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: _detailScaffold(
            title: '혈액 POCT',
            child: const BloodScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/demo/insights-partial',
        builder: (_, __) => ProviderScope(
          overrides: [
            healthSnapshotsProvider.overrideWith(
              (ref) => Stream.value([clinicalDemoPartialSnapshot]),
            ),
          ],
          child: _detailScaffold(
            title: '통합 인사이트',
            child: InsightDetailScreen(
              snapshotId: clinicalDemoPartialSnapshot.snapshotId,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/gut/:reportId',
        builder: (_, state) => _detailScaffold(
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
              reportId: state.pathParameters['reportId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/blood/trends',
        builder: (_, __) => _detailScaffold(
          title: '혈액 검사 추이',
          child: const BloodTrendsScreen(),
        ),
      ),
      GoRoute(
        path: '/blood/:reportId',
        builder: (_, state) => _detailScaffold(
          title: '혈액 검사 리포트',
          child: BloodReportScreen(
            reportId: state.pathParameters['reportId']!,
          ),
        ),
        routes: [
          for (final panel in ['liver', 'kidney', 'metabolic', 'lipid'])
            GoRoute(
              path: panel,
              builder: (_, state) => _detailScaffold(
                title: '혈액 패널 상세',
                child: BloodReportScreen(
                  reportId: state.pathParameters['reportId']!,
                  panel: panel,
                ),
              ),
            ),
          GoRoute(
            path: 'expert',
            builder: (_, state) => _detailScaffold(
              title: '혈액 전문가 상세',
              child: BloodExpertScreen(
                reportId: state.pathParameters['reportId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/insights/:snapshotId',
        builder: (_, state) => _detailScaffold(
          title: '통합 건강 상세',
          child: InsightDetailScreen(
            snapshotId: state.pathParameters['snapshotId']!,
          ),
        ),
      ),
    ],
  );
}

Widget _detailScaffold({required String title, required Widget child}) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(top: false, child: child),
    ),
  );
}

class _ClinicalDemoShell extends ConsumerWidget {
  const _ClinicalDemoShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    NavigationDestination(icon: Icon(Icons.home_rounded), label: '통합 홈'),
    NavigationDestination(
      icon: DfetAxisAssetIcon(axis: DfetAxis.gut, size: 28, active: false),
      selectedIcon: DfetAxisAssetIcon(axis: DfetAxis.gut, size: 28),
      label: '장 건강',
    ),
    NavigationDestination(
      icon: DfetAxisAssetIcon(axis: DfetAxis.blood, size: 28, active: false),
      selectedIcon: DfetAxisAssetIcon(axis: DfetAxis.blood, size: 28),
      label: '혈액',
    ),
    NavigationDestination(icon: Icon(Icons.hub_rounded), label: '인사이트'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = navigationShell.currentIndex == 0;
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: isToday
          ? null
          : AppBar(
              toolbarHeight: 66,
              backgroundColor: context.wellness.bgRoot,
              surfaceTintColor: Colors.transparent,
              title: const Text('D-FET 통합 케어'),
              actions: [
                TextButton(
                  onPressed: () => context.push('/demo/design-lab/atoms'),
                  child: const Text(
                    'LAB 01',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: isDark ? '라이트 모드' : '다크 모드',
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggleTheme(!isDark),
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _ClinicalDemoOverview extends StatelessWidget {
  const _ClinicalDemoOverview();

  @override
  Widget build(BuildContext context) {
    final snapshot = clinicalDemoSnapshots.first;
    return TodaySignalScreen(
      current: snapshot,
      previous: clinicalDemoSnapshots[1],
      insight: snapshot.insights.first,
      onOpenInsight: () => context.push('/insights/${snapshot.snapshotId}'),
    );
  }
}

class _GutSummaryEvidenceScreen extends ConsumerWidget {
  const _GutSummaryEvidenceScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(gutReportsProvider).valueOrNull ?? const [];
    final latest = reports.isEmpty ? null : reports.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          '통합 케어 홈',
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '케어유형에 맞는 최신 검사 요약을 홈 상단에서 확인합니다.',
          style: TextStyle(
            color: context.wellness.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        GutHealthSummaryCard(
          report: latest,
          onTap: () => context.go('/demo/gut'),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.wellness.bgSubtle,
            borderRadius: WellnessRadius.card,
          ),
          child: Text(
            '운동·식단 기록과 장·혈액 검사 결과를 같은 정보 위계로 연결합니다.',
            style: TextStyle(
              color: context.wellness.textSecondary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
