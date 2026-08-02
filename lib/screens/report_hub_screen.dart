import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/clinical_repository.dart';
import '../state/app_state.dart';
import '../state/clinical_state.dart';
import '../theme/tokens.dart';
import 'blood/blood_screen.dart';
import 'insights/insights_screen.dart';
import 'microbiome/microbiome_screen.dart';
import 'reports.dart';

class ReportHubScreen extends ConsumerStatefulWidget {
  const ReportHubScreen({super.key});

  @override
  ConsumerState<ReportHubScreen> createState() => _ReportHubScreenState();
}

class _ReportHubScreenState extends ConsumerState<ReportHubScreen> {
  String? selectedKey;

  CareType _careType() {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    return profile?.careType ?? ref.watch(guestCareTypeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final careType = _careType();
    final flags = ref.watch(featureFlagsProvider).valueOrNull ??
        const AppFeatureFlags.disabled();
    final sections = <_ReportSection>[
      if (careType != CareType.microbiome)
        const _ReportSection(
          keyName: 'fitness',
          label: '운동·식단',
          child: ReportsScreen(),
        ),
      if (careType != CareType.fitness && flags.gut)
        const _ReportSection(
          keyName: 'gut',
          label: '장 건강',
          child: MicrobiomeScreen(),
        ),
      if (flags.blood)
        const _ReportSection(
          keyName: 'blood',
          label: '혈액',
          child: BloodScreen(),
        ),
      if (flags.insights)
        const _ReportSection(
          keyName: 'insights',
          label: '통합',
          child: InsightsScreen(),
        ),
    ];
    if (sections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '현재 활성화된 리포트 기능이 없습니다.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final activeKey = sections.any((item) => item.keyName == selectedKey)
        ? selectedKey!
        : sections.first.keyName;
    final active = sections.firstWhere((item) => item.keyName == activeKey);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.wellness.bgSubtle,
              borderRadius: WellnessRadius.chip,
            ),
            child: Row(
              children: [
                for (final section in sections)
                  _segment(
                    context,
                    section,
                    selected: section.keyName == activeKey,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: PageStorageKey(active.keyName),
            child: active.child,
          ),
        ),
      ],
    );
  }

  Widget _segment(
    BuildContext context,
    _ReportSection section, {
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => selectedKey = section.keyName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.wellness.bgCard : Colors.transparent,
          borderRadius: WellnessRadius.chip,
          boxShadow: selected ? WellnessShadows.soft : null,
        ),
        child: Text(
          section.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? context.wellness.primaryDark
                : context.wellness.textTertiary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReportSection {
  const _ReportSection({
    required this.keyName,
    required this.label,
    required this.child,
  });

  final String keyName;
  final String label;
  final Widget child;
}
