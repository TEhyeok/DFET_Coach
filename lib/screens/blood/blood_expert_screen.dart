import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_card.dart';
import 'components/pro_blood_table.dart';

class BloodExpertScreen extends ConsumerWidget {
  const BloodExpertScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(bloodExpertReportProvider(reportId)).when(
          data: (report) {
            if (report == null) {
              return const Center(child: Text('전문가 리포트를 찾을 수 없습니다'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  '혈액 POCT 전문가 상세',
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '원본 단위와 정규화 결과를 함께 표시합니다.',
                  style: TextStyle(color: context.wellness.textSecondary),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(8),
                  child: ProBloodTable(rows: report.normalizedBiomarkers),
                ),
                if (report.analyzer != null) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '분석기 정보\n${report.analyzer}',
                      style: TextStyle(color: context.wellness.textSecondary),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('전문가 데이터를 불러오지 못했습니다')),
        );
  }
}
