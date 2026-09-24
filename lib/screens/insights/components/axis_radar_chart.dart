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
    if (values.any((value) => value == null)) {
      final missingLabels = <String>[
        for (var index = 0; index < values.length; index++)
          if (values[index] == null) axisLabels[index],
      ];
      return SizedBox(
        height: 230,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.radar_rounded,
                  size: 42,
                  color: context.wellness.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  '레이더 차트 산정 준비 중',
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '누락 축 ${missingLabels.join(', ')}은 0점으로 채우지 않습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wellness.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '검사 결과가 연결되면 동일 정책 기준으로 4축 균형을 표시합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                  .map((value) => RadarEntry(value: value!))
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
