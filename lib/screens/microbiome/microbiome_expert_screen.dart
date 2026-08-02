import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/clinical/alpha_metric_grid.dart';
import '../../widgets/clinical/genus_abundance_bar.dart';
import '../../widgets/clinical/pcoa_scatter.dart';
import 'components/microbiome_category_card.dart';

class MicrobiomeExpertScreen extends ConsumerWidget {
  const MicrobiomeExpertScreen({super.key, this.reportId});

  final String? reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reportId == null || reportId!.isEmpty) {
      return const Scaffold(body: Center(child: Text('전문가 리포트 ID가 필요합니다')));
    }
    final report = ref.watch(gutExpertReportProvider(reportId!));
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('전문가 상세 분석'),
      ),
      body: report.when(
        data: (value) => value == null
            ? const Center(child: Text('전문가 리포트를 찾을 수 없습니다'))
            : _ExpertBody(report: value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('권한이 없거나 리포트를 불러오지 못했습니다')),
      ),
    );
  }
}

class _ExpertBody extends StatelessWidget {
  const _ExpertBody({required this.report});

  final GutExpertReport report;

  @override
  Widget build(BuildContext context) {
    final metadata = report.metadata;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        Text(
          '${DateFormat('yyyy.MM.dd').format(report.summary.sampledAt)} · ${metadata['sampleId'] ?? 'Sample ID 없음'}',
          style: TextStyle(color: context.wellness.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: '베타 다양성 (Bray-Curtis PCoA)',
          icon: Icons.scatter_plot_rounded,
          iconColor: context.wellness.primary,
          children: [PcoaScatter(points: report.pcoa)],
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: '알파 다양성 4지표',
          icon: Icons.bubble_chart_rounded,
          iconColor: context.wellness.primaryLight,
          children: [AlphaMetricGrid(metrics: report.summary.alpha)],
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: 'Genus 상대적 풍부도',
          icon: Icons.bar_chart_rounded,
          iconColor: context.wellness.accent,
          children: [GenusAbundanceBar(items: report.genus)],
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: 'UniFrac',
          icon: Icons.account_tree_rounded,
          iconColor: context.wellness.info,
          children: [
            _metric(context, 'Weighted', report.weightedUnifrac),
            const Divider(height: 20),
            _metric(context, 'Unweighted', report.unweightedUnifrac),
          ],
        ),
        const SizedBox(height: 12),
        MicrobiomeCategoryCard(
          title: '분석 메타데이터',
          icon: Icons.fact_check_outlined,
          iconColor: context.wellness.textSecondary,
          children: [
            _meta(context, 'Assay', metadata['assay']),
            _meta(context, '플랫폼', metadata['sequencingPlatform']),
            _meta(context, '파이프라인', metadata['pipeline']),
            _meta(context, '버전', metadata['pipelineVersion']),
            _meta(context, 'Read count', metadata['readCount']),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '전문가용 원시 지표입니다. 임상적 해석은 승인된 전문가가 수행해야 합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.wellness.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, double? value) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(color: context.wellness.textSecondary))),
        Text(value?.toStringAsFixed(4) ?? '--',
            style: TextStyle(
                color: context.wellness.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _meta(BuildContext context, String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      color: context.wellness.textTertiary, fontSize: 12))),
          Expanded(
              child: Text(value?.toString() ?? '—',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: context.wellness.textPrimary, fontSize: 12))),
        ],
      ),
    );
  }
}
