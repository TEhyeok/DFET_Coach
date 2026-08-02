import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.value,
    required this.lower,
    required this.upper,
    this.unit,
  });

  final double value;
  final double? lower;
  final double? upper;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    if (lower == null && upper == null) {
      return Text(
        '승인된 정상범위가 없습니다',
        style: TextStyle(color: context.wellness.textTertiary, fontSize: 11),
      );
    }
    final low = lower ?? (upper! * 0.5);
    final high = upper ?? (lower! * 1.5);
    final span = (high - low).abs().clamp(0.0001, double.infinity);
    final domainLow = low - span * 0.5;
    final domainHigh = high + span * 0.5;
    final marker =
        ((value - domainLow) / (domainHigh - domainLow)).clamp(0.0, 1.0);
    final normalStart =
        ((low - domainLow) / (domainHigh - domainLow)).clamp(0.0, 1.0);
    final normalEnd =
        ((high - domainLow) / (domainHigh - domainLow)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 18,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.wellness.bgSubtle,
                      borderRadius: WellnessRadius.chip,
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * normalStart,
                  width: constraints.maxWidth * (normalEnd - normalStart),
                  top: 6,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.wellness.primarySubtle,
                      borderRadius: WellnessRadius.chip,
                    ),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth * marker - 7)
                      .clamp(0, constraints.maxWidth - 14),
                  top: 3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.wellness.primary,
                      border:
                          Border.all(color: context.wellness.bgCard, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_format(lower)}${unit == null ? '' : ' $unit'}',
                style: TextStyle(
                    color: context.wellness.textTertiary, fontSize: 10)),
            Text('${_format(upper)}${unit == null ? '' : ' $unit'}',
                style: TextStyle(
                    color: context.wellness.textTertiary, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  String _format(double? number) {
    if (number == null) return '제한 없음';
    return number == number.roundToDouble()
        ? number.round().toString()
        : number.toStringAsFixed(2);
  }
}
