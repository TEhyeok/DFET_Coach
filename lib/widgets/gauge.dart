import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.value});
  final int value; // 0~100
  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100).toDouble();
    final status = value >= 80 ? '건강함' : value >= 50 ? '양호함' : '주의 필요';

    // 빨-노-초 세그먼트 비율
    final sections = [
      _seg(context, 30, const Color(0xFFEF4444)),
      _seg(context, 30, const Color(0xFFF59E0B)),
      _seg(context, 40, const Color(0xFF35C56E)),
    ];
    // 실제 값 오버레이 (얇은 바)
    final indicator = _seg(context, v, AppColors.brandPrimary, stroke: 22);

    return Semantics(
      label: '웰니스 점수',
      value: '$value점',
      hint: '$status 상태입니다',
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(PieChartData(
            startDegreeOffset: 210,
            sectionsSpace: 0,
            centerSpaceRadius: 90,
            sections: sections,
          )),
          PieChart(PieChartData(
            startDegreeOffset: 210,
            sectionsSpace: 0,
            centerSpaceRadius: 90,
            sections: [indicator],
          )),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value', style: AppTextStyles.number),
              const SizedBox(height: 4),
              Text(status, style: AppTextStyles.bodySmall)
            ],
          )
        ],
      ),
    );
  }

  PieChartSectionData _seg(BuildContext context, double pct, Color c,
      {double stroke = 32}) {
    return PieChartSectionData(
      value: pct,
      color: c.withOpacity(.85),
      radius: 80,
      title: '',
      showTitle: false,
      borderSide: BorderSide(color: context.wellness.bgCard, width: 2),
    );
  }
}
