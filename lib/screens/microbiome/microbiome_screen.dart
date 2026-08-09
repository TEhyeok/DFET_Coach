import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../design_system/d_fet_axis_glyph.dart';
import '../../design_system/d_fet_axis_icon.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../state/user_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/clinical/alpha_metric_grid.dart';
import '../../widgets/clinical/comparison_card.dart';
import '../../widgets/clinical/composition_bar.dart';
import '../../widgets/clinical/score_gauge.dart';
import 'components/microbiome_category_card.dart';

class MicrobiomeScreen extends ConsumerWidget {
  const MicrobiomeScreen({super.key, this.reportId});

  final String? reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reportId != null) {
      return ref.watch(gutReportProvider(reportId!)).when(
            data: (report) => report == null
                ? const _ReportEmpty(message: '리포트를 찾을 수 없습니다')
                : _GutReportBody(report: report),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _ReportEmpty(message: '리포트를 불러오지 못했습니다'),
          );
    }
    return ref.watch(gutReportsProvider).when(
          data: (reports) => reports.isEmpty
              ? const _ReportEmpty(
                  message: '아직 장내미생물 검사 결과가 없습니다',
                  detail: '검사기관에서 결과가 연동되면 이곳에 표시됩니다.',
                )
              : _GutReportHub(reports: reports),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ReportEmpty(message: '장 건강 리포트를 불러오지 못했습니다'),
        );
  }
}

class _GutReportHub extends StatelessWidget {
  const _GutReportHub({required this.reports});

  final List<GutReport> reports;

  @override
  Widget build(BuildContext context) {
    final latest = reports.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _GutReportBody(report: latest, embedded: true),
        if (reports.length > 1) ...[
          const SizedBox(height: 12),
          Text('이전 검사',
              style: TextStyle(
                color: context.wellness.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          for (final report in reports.skip(1))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const DfetAxisAssetIcon(
                axis: DfetAxis.gut,
                size: 34,
              ),
              title: Text(DateFormat('yyyy.MM.dd').format(report.sampledAt)),
              subtitle: Text(report.overall.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/gut/${report.reportId}'),
            ),
        ],
      ],
    );
  }
}

class _GutReportBody extends ConsumerWidget {
  const _GutReportBody({required this.report, this.embedded = false});

  final GutReport report;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final canViewExpert =
        profile?.isTrainer == true || profile?.isAdmin == true;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 14),
        MicrobiomeCategoryCard(
          title: '장 건강 종합',
          icon: Icons.eco_rounded,
          iconColor: context.wellness.primary,
          children: [
            Center(
                child: ScoreGauge(
                    score: report.overall.score, label: report.overall.label)),
            const SizedBox(height: 8),
            Text(
              report.overall.score == null
                  ? '승인된 판정 정책이 등록되기 전까지 수치만 제공됩니다.'
                  : '이 점수는 건강관리 참고용이며 의료 진단이 아닙니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.wellness.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: '알파 다양성',
          icon: Icons.bubble_chart_rounded,
          iconColor: context.wellness.primaryLight,
          children: [
            AlphaMetricGrid(metrics: report.alpha),
            const SizedBox(height: 10),
            _detailLink(context, '알파 다양성 상세', 'alpha'),
          ],
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: 'Phylum 구성비',
          icon: Icons.stacked_bar_chart_rounded,
          iconColor: context.wellness.accent,
          children: [
            CompositionBar(items: report.phylum),
            const SizedBox(height: 10),
            _detailLink(context, '균총 구성 상세', 'composition'),
          ],
        ),
        const SizedBox(height: 12),
        ComparisonCard(
          title: '분석 정책',
          value: report.policyVersion ?? '미승인',
          label: report.overall.label,
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 8),
        if (canViewExpert) ...[
          _detailLink(context, '베타 다양성 PCoA', 'beta'),
          _detailLink(context, 'UniFrac 상세', 'unifrac'),
          _detailLink(context, '전문가용 통합 상세', 'expert'),
        ],
        const SizedBox(height: 14),
        Text(
          '본 리포트는 의료 진단이 아니며, 생활관리 참고용으로만 활용하십시오.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.wellness.textTertiary, fontSize: 11),
        ),
      ],
    );
    if (embedded) return content;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [content],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('장 건강 리포트',
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('yyyy.MM.dd').format(report.sampledAt)} 채취 · 16S rRNA V3-V4',
                style: TextStyle(
                    color: context.wellness.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const DfetAxisAssetIcon(axis: DfetAxis.gut, size: 46),
      ],
    );
  }

  Widget _detailLink(BuildContext context, String label, String route) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: TextStyle(color: context.wellness.textPrimary, fontSize: 13)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: context.wellness.textTertiary),
      onTap: () => context.push('/gut/${report.reportId}/$route'),
    );
  }
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty({required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DfetAxisAssetIcon(
              axis: DfetAxis.gut,
              size: 54,
              active: false,
            ),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontWeight: FontWeight.w700)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.wellness.textSecondary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
