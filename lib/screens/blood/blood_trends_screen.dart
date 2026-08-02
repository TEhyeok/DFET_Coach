import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_card.dart';
import 'components/blood_trend_chart.dart';

class BloodTrendsScreen extends ConsumerStatefulWidget {
  const BloodTrendsScreen({super.key});

  @override
  ConsumerState<BloodTrendsScreen> createState() => _BloodTrendsScreenState();
}

class _BloodTrendsScreenState extends ConsumerState<BloodTrendsScreen> {
  static const markerCodes = [
    'ALT',
    'AST',
    'TBIL',
    'DBIL',
    'TP',
    'ALB',
    'UREA',
    'CRE',
    'UA',
    'GLU',
    'TG',
    'CHOL',
    'HDL-C',
  ];
  String selected = 'GLU';

  @override
  Widget build(BuildContext context) {
    return ref.watch(bloodReportsProvider).when(
          data: (reports) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                '혈액 검사 추이',
                style: TextStyle(
                  color: context.wellness.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final code in markerCodes)
                    ChoiceChip(
                      label: Text(code),
                      selected: selected == code,
                      onSelected: (_) => setState(() => selected = code),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected,
                      style: TextStyle(
                        color: context.wellness.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    BloodTrendChart(reports: reports, markerCode: selected),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('추이 데이터를 불러오지 못했습니다')),
        );
  }
}
