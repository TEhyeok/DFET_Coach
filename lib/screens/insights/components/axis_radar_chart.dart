import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class AxisRadarChart extends StatelessWidget {
  const AxisRadarChart({super.key, required this.axes});

  final Map<String, double?> axes;

  static const axisKeys = ['fitness', 'diet', 'gut', 'blood'];
  static const axisLabels = ['운동', '식단', '장', '혈액'];

  @override
  Widget build(BuildContext context) {
    final values = axisKeys.map((key) => axes[key]).toList(growable: false);
    if (values.every((value) => value == null)) {
      return const SizedBox(
        height: 230,
        child: Center(child: Text('표시할 축 데이터가 없습니다')),
      );
    }

    return SizedBox(
      height: 250,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              fillColor: context.wellness.primary.withValues(alpha: 0.16),
              borderColor: context.wellness.primary,
              borderWidth: 2.5,
              entryRadius: 3,
              dataEntries: values
                  .map((value) => RadarEntry(value: value ?? 0))
                  .toList(growable: false),
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          radarBorderData: BorderSide(color: context.wellness.borderSubtle),
          gridBorderData: BorderSide(color: context.wellness.borderSubtle),
          tickCount: 4,
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 0),
          tickBorderData: BorderSide(color: context.wellness.borderSubtle),
          titleTextStyle: TextStyle(
            color: context.wellness.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          getTitle: (index, _) => RadarChartTitle(
            text: '${axisLabels[index]}\n${values[index]?.round() ?? '—'}',
          ),
        ),
      ),
    );
  }
}
