import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../state/user_state.dart';
import '../theme/tokens.dart';
import 'reports.dart';
import 'microbiome/microbiome_screen.dart';

/// 2026 개편: 통합 리포트 탭.
/// careType에 따라 내용 분기:
/// - fitness   : 운동/식단 통계(ReportsScreen)
/// - microbiome: 장 건강(MicrobiomeScreen)
/// - both      : 상단 세그먼트로 [운동/식단] ↔ [장 건강] 전환
class ReportHubScreen extends ConsumerStatefulWidget {
  const ReportHubScreen({super.key});

  @override
  ConsumerState<ReportHubScreen> createState() => _ReportHubScreenState();
}

class _ReportHubScreenState extends ConsumerState<ReportHubScreen> {
  int _segment = 0; // 0 = 운동/식단, 1 = 장 건강

  String _resolveCareType() {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile != null && profile.careType.isNotEmpty) {
      return profile.careType;
    }
    return ref.watch(guestCareTypeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final careType = _resolveCareType();

    if (careType == UserCareType.microbiome) {
      return const MicrobiomeScreen();
    }
    if (careType == UserCareType.fitness) {
      return const ReportsScreen();
    }

    // both: 세그먼트 토글
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
          child: _buildSegment(context),
        ),
        Expanded(
          child: _segment == 0
              ? const ReportsScreen()
              : const MicrobiomeScreen(),
        ),
      ],
    );
  }

  Widget _buildSegment(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.wellness.bgSubtle,
        borderRadius: WellnessRadius.chip,
      ),
      child: Row(
        children: [
          _segmentItem(context, '운동 · 식단', 0),
          _segmentItem(context, '장 건강', 1),
        ],
      ),
    );
  }

  Widget _segmentItem(BuildContext context, String label, int index) {
    final selected = _segment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? context.wellness.bgCard : Colors.transparent,
            borderRadius: WellnessRadius.chip,
            boxShadow: selected ? WellnessShadows.soft : null,
          ),
          child: Text(
            label,
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
      ),
    );
  }
}
