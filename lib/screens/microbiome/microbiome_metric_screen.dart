import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/d_fet_axis_glyph.dart';
import '../../design_system/d_fet_evidence.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/clinical/alpha_metric_grid.dart';
import '../../widgets/clinical/composition_bar.dart';
import '../../widgets/clinical/genus_abundance_bar.dart';
import '../../widgets/clinical/pcoa_scatter.dart';
import 'components/microbiome_category_card.dart';

enum MicrobiomeMetricSection { alpha, beta, composition, unifrac }

class MicrobiomeMetricScreen extends ConsumerWidget {
  const MicrobiomeMetricScreen({
    super.key,
    required this.reportId,
    required this.section,
  });

  final String reportId;
  final MicrobiomeMetricSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsExpert = section != MicrobiomeMetricSection.alpha &&
        section != MicrobiomeMetricSection.composition;
    final asyncValue =
        needsExpert ? ref.watch(gutExpertReportProvider(reportId)) : null;
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_ios_new_rounded)),
        title: Text(_title),
      ),
      body: needsExpert
          ? asyncValue!.when(
              data: (report) => report == null
                  ? const Center(child: Text('데이터가 없습니다'))
                  : _expertSection(context, report),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('상세 지표를 불러오지 못했습니다')),
            )
          : ref.watch(gutReportProvider(reportId)).when(
                data: (report) => report == null
                    ? const Center(child: Text('데이터가 없습니다'))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (section == MicrobiomeMetricSection.alpha)
                            AlphaMetricGrid(
                              metrics: report.alpha,
                              showRanges: true,
                            )
                          else
                            CompositionBar(
                                items: report.phylum, maxLegendItems: 12),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('상세 지표를 불러오지 못했습니다')),
              ),
    );
  }

  String get _title => switch (section) {
        MicrobiomeMetricSection.alpha => '알파 다양성',
        MicrobiomeMetricSection.beta => '베타 다양성',
        MicrobiomeMetricSection.composition => '균총 구성',
        MicrobiomeMetricSection.unifrac => 'UniFrac',
      };

  Widget _expertSection(BuildContext context, GutExpertReport report) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (section == MicrobiomeMetricSection.beta)
          MicrobiomeCategoryCard(
            title: 'Bray-Curtis PCoA',
            icon: Icons.scatter_plot_rounded,
            iconColor: context.wellness.primary,
            children: [PcoaScatter(points: report.pcoa)],
          )
        else
          MicrobiomeCategoryCard(
            title: 'Weighted / Unweighted',
            icon: Icons.account_tree_rounded,
            iconColor: context.wellness.primary,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _UnifracMetric(
                      label: 'WEIGHTED',
                      value: report.weightedUnifrac,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _UnifracMetric(
                      label: 'UNWEIGHTED',
                      value: report.unweightedUnifrac,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GenusAbundanceBar(items: report.genus),
            ],
          ),
      ],
    );
  }
}

class _UnifracMetric extends StatelessWidget {
  const _UnifracMetric({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.wellness.bgSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.wellness.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          DfetMetricValue(
            value: value?.toStringAsFixed(4),
            axis: DfetAxis.gut,
            compact: true,
          ),
        ],
      ),
    );
  }
}
