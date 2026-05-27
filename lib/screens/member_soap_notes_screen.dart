import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/soap_note.dart';
import '../state/soap_note_state.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../utils/responsive_layout.dart';
import '../widgets/app_card.dart';

class MemberSoapNotesScreen extends ConsumerWidget {
  const MemberSoapNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(soapNotesProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgRoot,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.bgRoot,
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        middle: Text('SOAP 노트'),
      ),
      child: SafeArea(
        child: notesAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, __) => const Center(
            child: Text('SOAP 노트를 불러올 수 없습니다', style: AppTextStyles.body),
          ),
          data: (notes) {
            if (notes.isEmpty) {
              return ListView(
                padding: ResponsiveLayout.pagePadding(context),
                children: const [
                  AppCard(
                    child: Text(
                      '트레이너가 공유한 SOAP 노트가 없습니다',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: ResponsiveLayout.pagePadding(context),
              children: [
                ResponsiveConstrainedBox(
                  maxWidth: 940,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final note in notes) ...[
                        _MemberSoapNoteCard(note: note),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberSoapNoteCard extends StatelessWidget {
  const _MemberSoapNoteCard({required this.note});

  final SoapNote note;

  @override
  Widget build(BuildContext context) {
    final structured = note.effectiveStructured;
    final assessment = _fallback(
      note.assessment,
      [
        structured.assessment['clinicalJudgement'],
        structured.assessment['problemList'],
      ],
    );
    final legacyGoals = _join([
      note.shortTermGoal,
      note.longTermGoal,
    ]);
    final goals = _fallback(
      legacyGoals,
      [
        structured.assessment['shortTermGoal'],
        structured.assessment['longTermGoal'],
      ],
    );
    final treatmentPlan = _fallback(
      note.treatmentPlan,
      [structured.plan['treatmentPlan']],
    );
    final homeExercise = _fallback(
      note.homeExercise,
      [structured.plan['homeExercise']],
    );
    final nextPlan = _fallback(
      note.nextPlan,
      [structured.plan['nextPlan']],
    );

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note.diagnosis.isEmpty ? 'SOAP 노트' : note.diagnosis,
                  style: AppTextStyles.h2,
                ),
              ),
              Text(
                DateFormat('yyyy.MM.dd').format(note.date),
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.trainerName ?? '담당 트레이너',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          _Block(title: '평가 요약', value: assessment),
          _Block(title: '목표', value: goals),
          _Block(title: '운동/관리 계획', value: treatmentPlan),
          _Block(title: '홈 운동', value: homeExercise),
          _Block(title: '다음 세션', value: nextPlan),
        ],
      ),
    );
  }

  static String _join(List<String> values) {
    return values.where((value) => value.trim().isNotEmpty).join('\n');
  }

  static String _fallback(String primary, List<dynamic> fallbackValues) {
    if (primary.trim().isNotEmpty) return primary;
    return fallbackValues
        .map((value) => value?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .join('\n');
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
