import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';

class HealthTimeline extends StatelessWidget {
  const HealthTimeline({super.key, required this.snapshots});

  final List<HealthSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return const Center(child: Text('비교할 스냅샷이 없습니다'));
    }
    return Column(
      children: [
        for (var index = 0; index < snapshots.length; index++)
          _TimelineRow(
            snapshot: snapshots[index],
            isLast: index == snapshots.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.snapshot, required this.isLast});

  final HealthSnapshot snapshot;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.wellness.primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: context.wellness.borderSubtle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('yyyy.MM.dd').format(snapshot.asOf)),
                subtitle: Text(
                  '${snapshot.label} · 완성도 ${(snapshot.completeness * 100).round()}%',
                ),
                trailing: Text(
                  snapshot.overallScore?.round().toString() ?? '—',
                  style: TextStyle(
                    color: context.wellness.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () => context.push('/insights/${snapshot.snapshotId}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
