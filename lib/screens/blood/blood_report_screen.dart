import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../design_system/d_fet_axis_glyph.dart';
import '../../design_system/d_fet_axis_icon.dart';
import '../../design_system/d_fet_evidence.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../state/user_state.dart';
import '../../theme/tokens.dart';
import 'components/biomarker_row.dart';
import 'components/blood_panel_card.dart';
import 'components/blood_summary_card.dart';

class BloodReportScreen extends ConsumerWidget {
  const BloodReportScreen({
    super.key,
    required this.reportId,
    this.panel,
  });

  final String reportId;
  final String? panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(bloodReportProvider(reportId)).when(
          data: (report) => report == null
              ? const _ReportMessage('리포트를 찾을 수 없습니다')
              : _BloodReportBody(report: report, selectedPanel: panel),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ReportMessage('리포트를 불러오지 못했습니다'),
        );
  }
}

class _BloodReportBody extends ConsumerWidget {
  const _BloodReportBody({required this.report, this.selectedPanel});

  final BloodReport report;
  final String? selectedPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final canViewExpert =
        profile?.isTrainer == true || profile?.isAdmin == true;
    final markers = selectedPanel == null
        ? report.biomarkers
        : report.biomarkers
            .where((marker) => marker.panel == selectedPanel)
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        DfetReportHeader(
          axis: DfetAxis.blood,
          eyebrow:
              selectedPanel == null ? 'POCT · FULL REPORT' : 'POCT · PANEL',
          title: selectedPanel == null
              ? '혈액 검사 리포트'
              : BloodPanelCard.labels[selectedPanel] ?? selectedPanel!,
          subtitle:
              '${DateFormat('yyyy.MM.dd').format(report.sampledAt)} 검사 · ${report.biomarkers.length.clamp(0, 13)}/13 항목 수신',
        ),
        const SizedBox(height: 16),
        if (selectedPanel == null) ...[
          BloodSummaryCard(report: report),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final entry in report.panels.entries)
                BloodPanelCard(
                  panel: entry.key,
                  summary: entry.value,
                  onTap: () => context.push(
                    '/blood/${report.reportId}/${entry.key}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '전체 검사 항목',
            style: TextStyle(
              color: context.wellness.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (markers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('수신된 항목이 없습니다')),
          )
        else
          for (final marker in markers) BiomarkerRow(marker: marker),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              Icon(Icons.show_chart_rounded, color: context.wellness.primary),
          title: const Text('시계열 추이 보기'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/blood/trends'),
        ),
        if (canViewExpert)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const DfetAxisAssetIcon(
              axis: DfetAxis.blood,
              size: 30,
            ),
            title: const Text('전문가용 원본·정규화 데이터'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/blood/${report.reportId}/expert'),
          ),
        const SizedBox(height: 12),
        DfetEvidenceRibbon(
          source: 'POCT 정규화 파이프라인',
          coverage: '${report.biomarkers.length.clamp(0, 13)}/13 항목',
          policyVersion: report.policyVersion,
          tone: report.reviewCount > 0 ||
                  report.biomarkers.length < 13 ||
                  report.policyVersion == null
              ? DfetEvidenceTone.pending
              : DfetEvidenceTone.neutral,
          detail: report.reviewCount > 0
              ? '지원하지 않는 단위나 불완전한 값 ${report.reviewCount}개는 자동 추측하지 않고 검토 대기로 분리했습니다. 승인된 값만 정상범위 판정과 추이에 사용합니다.'
              : '검사 항목은 표준 코드와 단위로 정규화했습니다. 표시된 정상범위와 점수 정책 버전을 리포트에 고정해 같은 결과를 다시 확인할 수 있습니다.',
        ),
        const SizedBox(height: 12),
        Text(
          '표시된 정상범위와 평가는 건강관리 참고용이며 의료 진단이 아닙니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.wellness.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}
