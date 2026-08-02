import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/clinical_reports.dart';
import '../../theme/tokens.dart';

class PcoaScatter extends StatelessWidget {
  const PcoaScatter({super.key, required this.points});

  final List<PcoaPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
          height: 180, child: Center(child: Text('PCoA 데이터 없음')));
    }
    final xs = points.map((point) => point.pc1);
    final ys = points.map((point) => point.pc2);
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final xPadding = ((maxX - minX).abs() * 0.15).clamp(0.05, double.infinity);
    final yPadding = ((maxY - minY).abs() * 0.15).clamp(0.05, double.infinity);
    return SizedBox(
      height: 230,
      child: ScatterChart(
        ScatterChartData(
          minX: minX - xPadding,
          maxX: maxX + xPadding,
          minY: minY - yPadding,
          maxY: maxY + yPadding,
          scatterSpots: points
              .map((point) => ScatterSpot(
                    point.pc1,
                    point.pc2,
                    dotPainter: FlDotCirclePainter(
                      radius: point.isSubject ? 8 : 5,
                      color: point.isSubject
                          ? context.wellness.primary
                          : context.wellness.textTertiary,
                      strokeWidth: point.isSubject ? 2 : 0,
                      strokeColor: context.wellness.bgCard,
                    ),
                  ))
              .toList(growable: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.wellness.borderSubtle),
            getDrawingVerticalLine: (_) =>
                FlLine(color: context.wellness.borderSubtle),
          ),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          scatterTouchData: ScatterTouchData(enabled: false),
        ),
      ),
    );
  }
}
