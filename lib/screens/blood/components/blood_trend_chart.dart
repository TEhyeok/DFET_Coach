import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';

class BloodTrendChart extends StatelessWidget {
  const BloodTrendChart({
    super.key,
    required this.reports,
    required this.markerCode,
  });

  final List<BloodReport> reports;
  final String markerCode;

  @override
  Widget build(BuildContext context) {
    final ordered = reports.reversed.toList(growable: false);
    final values = <({int index, BiomarkerResult marker})>[];
    for (var index = 0; index < ordered.length; index++) {
      final marker = ordered[index]
          .biomarkers
          .where((item) => item.code == markerCode)
          .firstOrNull;
      if (marker != null) values.add((index: index, marker: marker));
    }
    if (values.length < 2) {
      return const SizedBox(
          height: 180, child: Center(child: Text('추이를 표시하려면 검사 2회 이상이 필요합니다')));
    }
    final referenceRange = values.first.marker.referenceRange;
    final allValues = <double>[
      ...values.map((item) => item.marker.value),
      if (referenceRange?.lower != null) referenceRange!.lower!,
      if (referenceRange?.upper != null) referenceRange!.upper!,
    ];
    final minValue = allValues.reduce((a, b) => a < b ? a : b);
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final padding =
        ((maxValue - minValue).abs() * 0.25).clamp(1.0, double.infinity);
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: (minValue - padding).clamp(0, double.infinity),
          maxY: maxValue + padding,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.wellness.borderSubtle),
          ),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (referenceRange?.lower != null &&
                  referenceRange?.upper != null)
                HorizontalRangeAnnotation(
                  y1: referenceRange!.lower!,
                  y2: referenceRange.upper!,
                  color: context.wellness.energy.withValues(alpha: 0.12),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _axisLabel(value),
                      maxLines: 1,
                      style: TextStyle(
                        color: context.wellness.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: values
                  .map((item) =>
                      FlSpot(item.index.toDouble(), item.marker.value))
                  .toList(growable: false),
              isCurved: true,
              color: context.wellness.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  String _axisLabel(double value) =>
      value.abs() >= 10 ? value.round().toString() : value.toStringAsFixed(1);
}
