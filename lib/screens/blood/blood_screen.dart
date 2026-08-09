import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../design_system/d_fet_axis_glyph.dart';
import '../../design_system/d_fet_axis_icon.dart';
import '../../models/clinical_reports.dart';
import '../../state/clinical_state.dart';
import '../../theme/tokens.dart';
import 'components/blood_summary_card.dart';

class BloodScreen extends ConsumerWidget {
  const BloodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(bloodReportsProvider).when(
          data: (reports) => reports.isEmpty
              ? const _BloodEmpty()
              : _BloodHub(reports: reports),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _BloodEmpty(
            message: '혈액 검사 리포트를 불러오지 못했습니다',
          ),
        );
  }
}

class _BloodHub extends StatelessWidget {
  const _BloodHub({required this.reports});

  final List<BloodReport> reports;

  @override
  Widget build(BuildContext context) {
    final latest = reports.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '혈액 POCT',
                style: TextStyle(
                  color: context.wellness.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const DfetAxisAssetIcon(axis: DfetAxis.blood, size: 46),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '간·신장·대사·지질 13개 표준 항목',
          style: TextStyle(
            color: context.wellness.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        BloodSummaryCard(
          report: latest,
          onTap: () => context.push('/blood/${latest.reportId}'),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              Icon(Icons.show_chart_rounded, color: context.wellness.primary),
          title: const Text('검사 추이'),
          subtitle: Text('${reports.length}회의 검사 기록'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/blood/trends'),
        ),
        if (reports.length > 1) ...[
          const SizedBox(height: 14),
          Text(
            '이전 검사',
            style: TextStyle(
              color: context.wellness.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final report in reports.skip(1))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const DfetAxisAssetIcon(
                axis: DfetAxis.blood,
                size: 34,
              ),
              title: Text(DateFormat('yyyy.MM.dd').format(report.sampledAt)),
              subtitle: Text(
                '${report.biomarkers.length}/13 항목 · ${report.overall.label}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/blood/${report.reportId}'),
            ),
        ],
      ],
    );
  }
}

class _BloodEmpty extends StatelessWidget {
  const _BloodEmpty({
    this.message = '아직 혈액 검사 결과가 없습니다',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DfetAxisAssetIcon(
              axis: DfetAxis.blood,
              size: 54,
              active: false,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wellness.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '검사 결과가 연동되면 13개 항목을 표준 단위로 표시합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wellness.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
