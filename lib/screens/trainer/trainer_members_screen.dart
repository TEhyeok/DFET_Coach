import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/soap_note.dart';
import '../../state/soap_note_state.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/app_card.dart';
import '../../widgets/trainer_widget_label.dart';

class TrainerMembersScreen extends ConsumerWidget {
  const TrainerMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(soapNotesProvider);

    return notesAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, __) => const Center(
        child: Text('회원 정보를 불러올 수 없습니다', style: AppTextStyles.body),
      ),
      data: (notes) {
        final members = _buildMembers(notes);
        final highRiskCount =
            members.where((member) => member.riskLevel == 'high').length;
        final followUpCount =
            members.where((member) => member.needsFollowUp).length;

        return ListView(
          padding: ResponsiveLayout.pagePadding(context),
          children: [
            ResponsiveConstrainedBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummary(
                    members.length,
                    notes.length,
                    highRiskCount,
                    followUpCount,
                  ).trainerLabel('TR-FL-MBR-01'),
                  const SizedBox(height: 14),
                  if (members.isEmpty)
                    const AppCard(
                      child: Text(
                        'SOAP 노트를 작성하면 회원 관리 목록에 자동으로 표시됩니다',
                        style: AppTextStyles.body,
                      ),
                    ).trainerLabel('TR-FL-MBR-02')
                  else
                    for (final entry in members.asMap().entries) ...[
                      _MemberCard(member: entry.value)
                          .trainerLabel('TR-FL-MBR-LIST-${entry.key + 1}'),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummary(
    int memberCount,
    int noteCount,
    int highRiskCount,
    int followUpCount,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: Text('회원 관리 현황', style: AppTextStyles.h2)),
              Icon(
                CupertinoIcons.person_2_fill,
                color: AppColors.brandPrimary,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: '관리 회원', value: '$memberCount'),
              const SizedBox(width: 10),
              _Metric(label: 'SOAP 노트', value: '$noteCount'),
              const SizedBox(width: 10),
              _Metric(label: '고위험', value: '$highRiskCount'),
              const SizedBox(width: 10),
              _Metric(label: '재평가', value: '$followUpCount'),
            ],
          ),
        ],
      ),
    );
  }

  List<_MemberSummary> _buildMembers(List<SoapNote> notes) {
    final byKey = <String, List<SoapNote>>{};

    for (final note in notes) {
      final key = note.memberId?.isNotEmpty == true
          ? note.memberId!
          : note.memberEmail?.isNotEmpty == true
              ? note.memberEmail!
              : note.memberName;
      byKey.putIfAbsent(key, () => []).add(note);
    }

    final members = byKey.values.map((memberNotes) {
      memberNotes.sort((a, b) => b.date.compareTo(a.date));
      final latest = memberNotes.first;
      final previous = memberNotes.length > 1 ? memberNotes[1] : null;
      final painDelta = previous == null
          ? null
          : (latest.painNow ?? latest.painWorst ?? 0) -
              (previous.painNow ?? previous.painWorst ?? 0);

      return _MemberSummary(
        name: latest.memberName,
        email: latest.memberEmail,
        latestDate: latest.date,
        noteCount: memberNotes.length,
        latestAssessment: latest.assessment,
        riskLevel: latest.riskLevel,
        completion: latest.completionPercent,
        painNow: latest.painNow ?? latest.painWorst,
        painDelta: painDelta,
        followUpDate: latest.followUpDate,
      );
    }).toList()
      ..sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return members;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.kpi),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final _MemberSummary member;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              CupertinoIcons.person_crop_circle,
              color: AppColors.info,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: AppTextStyles.h3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _RiskChip(level: member.riskLevel),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  member.email ?? '회원 이메일 미입력',
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusChip(label: '${member.completion}% 완료'),
                    _StatusChip(label: member.painLabel),
                    if (member.needsFollowUp)
                      const _StatusChip(label: '재평가 필요'),
                  ],
                ),
                if (member.latestAssessment.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    member.latestAssessment,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${member.noteCount}건',
                style: AppTextStyles.h3.copyWith(color: AppColors.brandPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MM.dd').format(member.latestDate),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberSummary {
  const _MemberSummary({
    required this.name,
    required this.email,
    required this.latestDate,
    required this.noteCount,
    required this.latestAssessment,
    required this.riskLevel,
    required this.completion,
    required this.painNow,
    required this.painDelta,
    required this.followUpDate,
  });

  final String name;
  final String? email;
  final DateTime latestDate;
  final int noteCount;
  final String latestAssessment;
  final String riskLevel;
  final int completion;
  final int? painNow;
  final int? painDelta;
  final DateTime? followUpDate;

  bool get needsFollowUp {
    final dueDate = followUpDate;
    if (dueDate != null) {
      return !dueDate.isAfter(DateTime.now());
    }
    return DateTime.now().difference(latestDate).inDays >= 14;
  }

  String get painLabel {
    if (painNow == null) return '통증 미입력';
    if (painDelta == null) return '통증 $painNow';
    if (painDelta == 0) return '통증 $painNow / 변화 없음';
    final sign = painDelta! > 0 ? '+' : '';
    return '통증 $painNow ($sign$painDelta)';
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'high' => AppColors.danger,
      'medium' => AppColors.warn,
      _ => AppColors.success,
    };
    final label = switch (level) {
      'high' => '고위험',
      'medium' => '중위험',
      _ => '저위험',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: Colors.white60),
      ),
    );
  }
}
