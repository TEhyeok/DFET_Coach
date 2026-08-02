import 'package:flutter/material.dart';
import '../../models/clinical_reports.dart';
import '../../theme/tokens.dart';

class CompositionBar extends StatelessWidget {
  const CompositionBar(
      {super.key, required this.items, this.maxLegendItems = 5});

  final List<TaxonAbundance> items;
  final int maxLegendItems;

  static const _colors = [
    WellnessColors.primary,
    WellnessColors.primaryLight,
    WellnessColors.accent,
    WellnessColors.info,
    WellnessColors.warning,
    WellnessColors.textTertiary,
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('구성비 데이터가 없습니다',
          style: TextStyle(color: context.wellness.textTertiary));
    }
    final visible =
        items.where((item) => item.value > 0).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: WellnessRadius.chip,
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (var index = 0; index < visible.length; index++)
                  Expanded(
                    flex: (visible[index].value * 100).round().clamp(1, 10000),
                    child: ColoredBox(color: _colors[index % _colors.length]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (var index = 0;
                  index < visible.length && index < maxLegendItems;
                  index++)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: _LegendItem(
                    color: _colors[index % _colors.length],
                    label:
                        '${visible[index].name} ${visible[index].value.toStringAsFixed(1)}%',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: context.wellness.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
