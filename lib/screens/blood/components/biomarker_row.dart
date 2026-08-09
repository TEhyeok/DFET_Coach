import 'package:flutter/material.dart';
import '../../../models/clinical_reports.dart';
import '../../../theme/d_fet_typography.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/clinical/range_bar.dart';

class BiomarkerRow extends StatelessWidget {
  const BiomarkerRow({super.key, required this.marker});

  final BiomarkerResult marker;

  @override
  Widget build(BuildContext context) {
    final range = marker.referenceRange;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: context.wellness.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(marker.code,
                    style: DfetTypography.dataStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              Expanded(
                child: Text(
                  '${_format(marker.value)} ${marker.unit}',
                  style: DfetTypography.dataStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: marker.status == 'unscored'
                      ? context.wellness.bgSubtle
                      : context.wellness.primarySubtle,
                  borderRadius: WellnessRadius.chip,
                ),
                child: Text(marker.label,
                    style: TextStyle(
                      color: marker.status == 'unscored'
                          ? context.wellness.textSecondary
                          : context.wellness.primaryDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeBar(
            value: marker.value,
            lower: range?.lower,
            upper: range?.upper,
            unit: range?.unit ?? marker.unit,
          ),
        ],
      ),
    );
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
}
