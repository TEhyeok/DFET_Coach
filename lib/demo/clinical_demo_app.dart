import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_system/d_fet_axis_glyph.dart';
import '../design_system/d_fet_axis_icon.dart';
import '../screens/blood/blood_expert_screen.dart';
import '../screens/blood/blood_report_screen.dart';
import '../screens/blood/blood_screen.dart';
import '../screens/blood/blood_trends_screen.dart';
import '../screens/blood/components/blood_summary_card.dart';
import '../screens/insights/insight_detail_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/insights/components/integrated_score_card.dart';
import '../screens/insights/components/action_recommendation_card.dart';
import '../screens/insights/components/progress_efficacy_card.dart';
import '../screens/microbiome/microbiome_expert_screen.dart';
import '../screens/microbiome/microbiome_metric_screen.dart';
import '../screens/microbiome/microbiome_screen.dart';
import '../services/clinical_repository.dart';
import '../state/clinical_state.dart';
import '../state/theme_provider.dart';
import '../state/user_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
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
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        toolbarHeight: 66,
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'D-FET 통합 케어',
              style: TextStyle(
                color: context.wellness.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '합성 데이터 · 운영 DB 미사용',
              style: TextStyle(
                color: context.wellness.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
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
    final gut = clinicalDemoGutReports.first;
    final blood = clinicalDemoBloodReports.first;
    final snapshot = clinicalDemoSnapshots.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.wellness.primarySubtle,
                  borderRadius: WellnessRadius.card,
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: context.wellness.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '통합 케어 회원',
                      style: TextStyle(
                        color: context.wellness.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '운동 · 식단 · 장내미생물 · 혈액 4축',
                      style: TextStyle(
                        color: context.wellness.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: context.wellness.primarySubtle,
                  borderRadius: WellnessRadius.chip,
                ),
                child: Text(
                  'BOTH',
                  style: TextStyle(
                    color: context.wellness.primaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ProgressEfficacyCard(
          current: snapshot,
          previous: clinicalDemoSnapshots[1],
          onTap: () => context.push('/insights/${snapshot.snapshotId}'),
        ),
        const SizedBox(height: 14),
        ActionRecommendationCard(insight: snapshot.insights.first),
        const SizedBox(height: 18),
        Text(
          '현재 데이터',
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        GutHealthSummaryCard(
          report: gut,
          onTap: () => context.go('/demo/gut'),
        ),
        const SizedBox(height: 10),
        BloodSummaryCard(
          report: blood,
          onTap: () => context.go('/demo/blood'),
        ),
        const SizedBox(height: 10),
        IntegratedScoreCard(
          snapshot: snapshot,
          onTap: () => context.push('/insights/${snapshot.snapshotId}'),
        ),
        const SizedBox(height: 18),
        Text(
          '전문가 리포트',
          style: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/gut/${gut.reportId}/expert',
                ),
                icon: const Icon(Icons.biotech_rounded),
                label: const Text('16S 전문가'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/blood/${blood.reportId}/expert',
                ),
                icon: const Icon(Icons.science_rounded),
                label: const Text('혈액 전문가'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '화면의 점수와 검사값은 개발·검수용 합성 데이터이며 의료 진단에 사용할 수 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.wellness.textTertiary,
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
