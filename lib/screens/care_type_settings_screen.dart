import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';

class CareTypeSettingsScreen extends ConsumerStatefulWidget {
  const CareTypeSettingsScreen({
    super.key,
    this.requiredConfirmation = false,
  });

  final bool requiredConfirmation;

  @override
  ConsumerState<CareTypeSettingsScreen> createState() =>
      _CareTypeSettingsScreenState();
}

class _CareTypeSettingsScreenState
    extends ConsumerState<CareTypeSettingsScreen> {
  CareType? selected;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    selected ??= profile?.careType ?? ref.watch(guestCareTypeProvider);

    return PopScope(
      canPop: !widget.requiredConfirmation,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            widget.requiredConfirmation ? '케어 유형을 확인해 주세요' : '케어 유형',
            style: TextStyle(
              color: context.wellness.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '선택한 유형에 따라 홈과 리포트 구성이 달라집니다. 언제든 변경할 수 있습니다.',
            style: TextStyle(
              color: context.wellness.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _option(
            CareType.fitness,
            '운동·식단 케어',
            '운동 기록, 식단 분석, 코칭 중심',
            Icons.fitness_center_rounded,
          ),
          const SizedBox(height: 10),
          _option(
            CareType.microbiome,
            '장 건강 케어',
            '16S 검사, 다양성, 균총 구성 중심',
            Icons.biotech_rounded,
          ),
          const SizedBox(height: 10),
          _option(
            CareType.both,
            '통합 케어',
            '운동·식단·장·혈액을 한 번에 관리',
            Icons.hub_rounded,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(saving ? '저장 중…' : '선택 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    CareType type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = selected == type;
    return AppCard(
      onTap: () => setState(() => selected = type),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.wellness.primarySubtle
                  : context.wellness.bgSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: context.wellness.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isSelected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected
                ? context.wellness.primary
                : context.wellness.textTertiary,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final careType = selected;
    if (careType == null) return;
    setState(() => saving = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('guestCareType', careType.wireValue);
      ref.read(guestCareTypeProvider.notifier).state = careType;

      final user = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (user != null && profile != null) {
        await ref.read(firestoreServiceProvider).saveUserProfile(
              profile.copyWith(
                careType: careType,
                careTypeVersion: 1,
                careTypeConfirmedAt: DateTime.now(),
              ),
            );
        ref.invalidate(userProfileProvider);
      }
      if (mounted) context.go('/home/dashboard');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
