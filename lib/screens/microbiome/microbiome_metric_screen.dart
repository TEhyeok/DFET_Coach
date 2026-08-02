import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                            AlphaMetricGrid(metrics: report.alpha)
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
              Text(
                  'Weighted  ${report.weightedUnifrac?.toStringAsFixed(4) ?? '--'}'),
              const SizedBox(height: 10),
              Text(
                  'Unweighted  ${report.unweightedUnifrac?.toStringAsFixed(4) ?? '--'}'),
              const SizedBox(height: 16),
              GenusAbundanceBar(items: report.genus),
            ],
          ),
      ],
    );
  }
}
