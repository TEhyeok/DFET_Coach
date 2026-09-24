import 'package:flutter/material.dart';
import '../../models/clinical_reports.dart';
import '../../theme/tokens.dart';
import 'range_bar.dart';

class AlphaMetricGrid extends StatelessWidget {
  const AlphaMetricGrid({
    super.key,
    required this.metrics,
    this.showRanges = false,
  });

  final Map<String, MetricAssessment> metrics;
  final bool showRanges;

  static const labels = {
    'shannon': 'Shannon',
    'simpson': 'Simpson',
    'chao1': 'Chao1',
    'observedOtus': 'Observed OTUs',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final baseRatio = showRanges
            ? (columns == 4 ? 0.82 : 0.96)
            : (columns == 4 ? 1.15 : 1.4);
        final accessibleRatio =
            baseRatio / (1 + (textScale - 1).clamp(0, 1) * 1.7);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: accessibleRatio,
          children: labels.entries.map((entry) {
            final metric = metrics[entry.key];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.wellness.bgSubtle,
                borderRadius: WellnessRadius.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.wellness.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(metric == null ? '--' : _format(metric.value),
                      style: TextStyle(
                          color: context.wellness.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(metric?.label ?? '데이터 없음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.wellness.textTertiary, fontSize: 10)),
                  if (showRanges && metric != null) ...[
                    const SizedBox(height: 7),
                    RangeBar(
                      value: metric.value,
                      lower: metric.referenceRange?.lower,
                      upper: metric.referenceRange?.upper,
                      unit: metric.referenceRange?.unit,
                    ),
                  ],
                ],
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(3);
}
