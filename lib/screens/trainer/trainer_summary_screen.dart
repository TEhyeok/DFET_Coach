import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/soap_note.dart';
import '../../state/soap_note_state.dart';
import '../../theme/tokens.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/trainer_widget_label.dart';

class TrainerSummaryScreen extends ConsumerWidget {
  const TrainerSummaryScreen({
    super.key,
    this.onOpenNativeHome,
    required this.onOpenSoap,
    required this.onOpenMembers,
  });

  final VoidCallback? onOpenNativeHome;
  final VoidCallback onOpenSoap;
  final VoidCallback onOpenMembers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(soapNotesProvider);

    return notesAsync.when(
      loading: () => const ColoredBox(
        color: AppleColors.bgPrimary,
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (_, __) => const ColoredBox(
        color: AppleColors.bgPrimary,
        child: Center(
          child: Text(
            '요약을 불러올 수 없습니다',
            style: TextStyle(color: AppleColors.labelSecondary),
          ),
        ),
      ),
      data: (notes) {
        final data = _TrainerSummaryData.fromNotes(notes);
        return _TrainerSummaryContent(
          data: data,
          onOpenNativeHome: onOpenNativeHome,
          onOpenSoap: onOpenSoap,
          onOpenMembers: onOpenMembers,
        );
      },
    );
  }
}

class _TrainerSummaryContent extends StatelessWidget {
  const _TrainerSummaryContent({
    required this.data,
    required this.onOpenNativeHome,
    required this.onOpenSoap,
    required this.onOpenMembers,
  });

  final _TrainerSummaryData data;
  final VoidCallback? onOpenNativeHome;
  final VoidCallback onOpenSoap;
  final VoidCallback onOpenMembers;

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final now = DateTime.now();

    return ColoredBox(
      color: AppleColors.bgPrimary,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 32 : 18,
          isTablet ? 28 : 18,
          isTablet ? 32 : 18,
          isTablet ? 40 : 28,
        ),
        child: ResponsiveConstrainedBox(
          maxWidth: 1180,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useTwoPane = constraints.maxWidth >= 980;
              final mainColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryHeader(
                    date: now,
                    onOpenNativeHome: onOpenNativeHome,
                  ).trainerLabel('TR-FL-SUM-01'),
                  const SizedBox(height: 18),
                  _PriorityCard(
                    data: data,
                    onOpenSoap: onOpenSoap,
                    onOpenMembers: onOpenMembers,
                  ).trainerLabel('TR-FL-SUM-02'),
                  const SizedBox(height: 16),
                  _MetricGrid(data: data).trainerLabel('TR-FL-SUM-03'),
                  const SizedBox(height: 16),
                  _TrendCard(data: data).trainerLabel('TR-FL-SUM-08'),
                  if (!useTwoPane) ...[
                    const SizedBox(height: 16),
                    _TodayActionCard(
                      data: data,
                      onOpenSoap: onOpenSoap,
                      onOpenMembers: onOpenMembers,
                    ).trainerLabel('TR-FL-SUM-09'),
                    const SizedBox(height: 16),
                    _RecentSoapCard(notes: data.latestNotes)
                        .trainerLabel('TR-FL-SUM-10'),
                  ],
                ],
              );

              if (!useTwoPane) return mainColumn;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: mainColumn),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TodayActionCard(
                          data: data,
                          onOpenSoap: onOpenSoap,
                          onOpenMembers: onOpenMembers,
                        ).trainerLabel('TR-FL-SUM-09'),
                        const SizedBox(height: 16),
                        _RecentSoapCard(notes: data.latestNotes)
                            .trainerLabel('TR-FL-SUM-10'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.date,
    required this.onOpenNativeHome,
  });

  final DateTime date;
  final VoidCallback? onOpenNativeHome;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('M월 d일').format(date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  color: AppleColors.labelSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                '트레이너 요약',
                style: TextStyle(
                  color: AppleColors.labelPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        if (onOpenNativeHome != null) ...[
          const SizedBox(width: 14),
          _NativeHomeButton(onPressed: onOpenNativeHome!),
        ],
      ],
    );
  }
}

class _NativeHomeButton extends StatelessWidget {
  const _NativeHomeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      color: AppleColors.blue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      onPressed: onPressed,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.sidebar_left,
            color: AppleColors.blue,
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
            'iPadOS 보기',
            style: TextStyle(
              color: AppleColors.blue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.data,
    required this.onOpenSoap,
    required this.onOpenMembers,
  });

  final _TrainerSummaryData data;
  final VoidCallback onOpenSoap;
  final VoidCallback onOpenMembers;

  @override
  Widget build(BuildContext context) {
    final priority = data.priority;
    final actionLabel =
        data.followUpCount > 0 || data.highRiskCount > 0 ? '회원 확인' : 'SOAP 기록';
    final action = data.followUpCount > 0 || data.highRiskCount > 0
        ? onOpenMembers
        : onOpenSoap;

    return _HealthCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: priority.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(priority.icon, color: priority.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priority.eyebrow,
                  style: const TextStyle(
                    color: AppleColors.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  priority.title,
                  style: const TextStyle(
                    color: AppleColors.labelPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  priority.message,
                  style: const TextStyle(
                    color: AppleColors.labelSecondary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: AppleColors.blue,
            borderRadius: BorderRadius.circular(999),
            onPressed: action,
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data});

  final _TrainerSummaryData data;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricItem(
        title: '오늘 세션',
        value: '${data.todaySessions}',
        unit: '건',
        icon: CupertinoIcons.calendar,
        color: AppleColors.blue,
      ),
      _MetricItem(
        title: '관리 회원',
        value: '${data.memberCount}',
        unit: '명',
        icon: CupertinoIcons.person_2,
        color: AppleColors.purple,
      ),
      _MetricItem(
        title: '주의 필요',
        value: '${data.attentionCount}',
        unit: '명',
        icon: CupertinoIcons.exclamationmark_triangle,
        color: data.attentionCount > 0 ? AppleColors.orange : AppleColors.green,
      ),
      _MetricItem(
        title: 'SOAP 미완료',
        value: '${data.draftCount}',
        unit: '건',
        icon: CupertinoIcons.doc_text,
        color: data.draftCount > 0 ? AppleColors.orange : AppleColors.green,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: width, child: _MetricCard(metric: metric))
                  .trainerLabel('TR-FL-SUM-${metrics.indexOf(metric) + 4}'),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricItem metric;

  @override
  Widget build(BuildContext context) {
    return _HealthCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: metric.color, size: 20),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: metric.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            metric.title,
            style: const TextStyle(
              color: AppleColors.labelSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metric.value,
                style: const TextStyle(
                  color: AppleColors.labelPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  metric.unit,
                  style: const TextStyle(
                    color: AppleColors.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});

  final _TrainerSummaryData data;

  @override
  Widget build(BuildContext context) {
    return _HealthCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '회원 상태 변화',
                      style: TextStyle(
                        color: AppleColors.labelPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '최근 SOAP 기준 통증과 완료율',
                      style: TextStyle(
                        color: AppleColors.labelSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _HealthPill(
                text: data.memberCount == 0
                    ? '기록 없음'
                    : '평균 통증 ${data.averagePainLabel}',
                color: data.averagePain >= 7
                    ? AppleColors.red
                    : data.averagePain >= 5
                        ? AppleColors.orange
                        : AppleColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: _HealthTrendChart(points: data.trendPoints),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(label: '통증', color: AppleColors.red),
              const SizedBox(width: 14),
              _LegendDot(label: 'SOAP 완료율', color: AppleColors.blue),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  const _TodayActionCard({
    required this.data,
    required this.onOpenSoap,
    required this.onOpenMembers,
  });

  final _TrainerSummaryData data;
  final VoidCallback onOpenSoap;
  final VoidCallback onOpenMembers;

  @override
  Widget build(BuildContext context) {
    final signals = data.attentionMembers;

    return _HealthCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '오늘 볼 회원',
                  style: TextStyle(
                    color: AppleColors.labelPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                onPressed: onOpenMembers,
                child: const Text(
                  '전체 보기',
                  style: TextStyle(
                    color: AppleColors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (signals.isEmpty)
            const _EmptyInlineState(
              icon: CupertinoIcons.checkmark_circle,
              title: '즉시 확인할 위험 신호가 없습니다',
              message: 'SOAP 기록이 쌓이면 재평가와 통증 변화가 여기에 표시됩니다.',
            )
          else
            for (final signal in signals.take(4)) ...[
              _AttentionMemberRow(signal: signal),
              if (signal != signals.take(4).last) const _ThinDivider(),
            ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'SOAP 기록',
                  icon: CupertinoIcons.doc_text,
                  color: AppleColors.blue,
                  onPressed: onOpenSoap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: '회원 관리',
                  icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                  color: AppleColors.purple,
                  onPressed: onOpenMembers,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSoapCard extends StatelessWidget {
  const _RecentSoapCard({required this.notes});

  final List<SoapNote> notes;

  @override
  Widget build(BuildContext context) {
    return _HealthCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 SOAP',
            style: TextStyle(
              color: AppleColors.labelPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            const _EmptyInlineState(
              icon: CupertinoIcons.doc_text,
              title: '저장된 SOAP가 없습니다',
              message: '첫 SOAP를 저장하면 최근 기록과 회원 변화가 표시됩니다.',
            )
          else
            for (final note in notes.take(5)) ...[
              _RecentSoapRow(note: note),
              if (note != notes.take(5).last) const _ThinDivider(),
            ],
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppleColors.bgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppleColors.separatorNonOpaque),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionMemberRow extends StatelessWidget {
  const _AttentionMemberRow({required this.signal});

  final _MemberSignal signal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: signal.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              signal.initial,
              style: TextStyle(
                color: signal.color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppleColors.labelPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signal.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppleColors.labelSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            signal.trailing,
            style: TextStyle(
              color: signal.color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSoapRow extends StatelessWidget {
  const _RecentSoapRow({required this.note});

  final SoapNote note;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('M.d').format(note.date);
    final riskColor = switch (note.riskLevel) {
      'high' => AppleColors.red,
      'medium' => AppleColors.orange,
      _ => AppleColors.green,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              date,
              style: const TextStyle(
                color: AppleColors.labelSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppleColors.labelPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note.diagnosis.trim().isEmpty ? '평가 항목 미입력' : note.diagnosis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppleColors.labelSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HealthPill(
            text: '${note.completionPercent}%',
            color: riskColor,
          ),
        ],
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  const _EmptyInlineState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppleColors.bgPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppleColors.blue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppleColors.labelPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppleColors.labelSecondary,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppleColors.separatorNonOpaque);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppleColors.labelSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HealthTrendChart extends StatelessWidget {
  const _HealthTrendChart({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HealthTrendPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _HealthTrendPainter extends CustomPainter {
  const _HealthTrendPainter(this.points);

  final List<_TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppleColors.separatorNonOpaque
      ..strokeWidth = 1;
    final painPaint = Paint()
      ..color = AppleColors.red
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    final completionPaint = Paint()
      ..color = AppleColors.blue
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final chartPoints = points.isEmpty
        ? const [
            _TrendPoint(label: '1', pain: 0, completion: 0),
            _TrendPoint(label: '2', pain: 0, completion: 0),
            _TrendPoint(label: '3', pain: 0, completion: 0),
            _TrendPoint(label: '4', pain: 0, completion: 0),
          ]
        : points;
    final step = chartPoints.length <= 1
        ? size.width
        : size.width / (chartPoints.length - 1);

    Path linePath(Color color, double Function(_TrendPoint) valueOf) {
      final path = Path();
      for (var index = 0; index < chartPoints.length; index++) {
        final point = chartPoints[index];
        final x = index * step;
        final normalized = valueOf(point).clamp(0.0, 1.0);
        final y = size.height - normalized * size.height;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    canvas.drawPath(
      linePath(AppleColors.red, (point) => point.pain / 10),
      points.isEmpty
          ? (painPaint..color = AppleColors.red.withValues(alpha: 0.18))
          : painPaint,
    );
    canvas.drawPath(
      linePath(AppleColors.blue, (point) => point.completion / 100),
      points.isEmpty
          ? (completionPaint..color = AppleColors.blue.withValues(alpha: 0.18))
          : completionPaint,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < chartPoints.length; index++) {
      final point = chartPoints[index];
      final x = index * step;
      dotPaint.color = points.isEmpty
          ? AppleColors.red.withValues(alpha: 0.18)
          : AppleColors.red;
      canvas.drawCircle(
        Offset(
            x, size.height - (point.pain / 10).clamp(0.0, 1.0) * size.height),
        4,
        dotPaint,
      );
      dotPaint.color = points.isEmpty
          ? AppleColors.blue.withValues(alpha: 0.18)
          : AppleColors.blue;
      canvas.drawCircle(
        Offset(
          x,
          size.height - (point.completion / 100).clamp(0.0, 1.0) * size.height,
        ),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HealthTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _TrainerSummaryData {
  const _TrainerSummaryData({
    required this.todaySessions,
    required this.memberCount,
    required this.highRiskCount,
    required this.followUpCount,
    required this.draftCount,
    required this.averagePain,
    required this.latestNotes,
    required this.attentionMembers,
    required this.trendPoints,
  });

  final int todaySessions;
  final int memberCount;
  final int highRiskCount;
  final int followUpCount;
  final int draftCount;
  final double averagePain;
  final List<SoapNote> latestNotes;
  final List<_MemberSignal> attentionMembers;
  final List<_TrendPoint> trendPoints;

  int get attentionCount => math.max(highRiskCount, attentionMembers.length);

  String get averagePainLabel {
    if (averagePain <= 0) return '-';
    return averagePain.toStringAsFixed(1);
  }

  _Priority get priority {
    if (followUpCount > 0) {
      return _Priority(
        eyebrow: '재평가 필요',
        title: '$followUpCount명의 회원을 먼저 확인하세요',
        message: '재평가일이 지났거나 마지막 기록 후 14일 이상 지난 회원이 있습니다.',
        icon: CupertinoIcons.calendar,
        color: AppleColors.orange,
      );
    }
    if (highRiskCount > 0) {
      return _Priority(
        eyebrow: '위험도 상승',
        title: '고위험 회원 $highRiskCount명',
        message: '통증 또는 SOAP 위험도가 높은 회원을 오늘 세션 전에 확인하세요.',
        icon: CupertinoIcons.exclamationmark_triangle,
        color: AppleColors.red,
      );
    }
    if (draftCount > 0) {
      return _Priority(
        eyebrow: '정리 필요',
        title: '미완료 SOAP $draftCount건',
        message: '수업 후 정리가 필요한 SOAP 노트가 남아 있습니다.',
        icon: CupertinoIcons.doc_text,
        color: AppleColors.blue,
      );
    }
    return const _Priority(
      eyebrow: '오늘 상태',
      title: '관리 흐름이 안정적입니다',
      message: '새 SOAP를 기록하면 회원 변화와 주의 항목이 자동으로 요약됩니다.',
      icon: CupertinoIcons.heart,
      color: AppleColors.green,
    );
  }

  factory _TrainerSummaryData.fromNotes(List<SoapNote> notes) {
    final now = DateTime.now();
    final sorted = [...notes]..sort((a, b) => b.date.compareTo(a.date));
    final byMember = <String, List<SoapNote>>{};

    for (final note in sorted) {
      final key = note.memberId?.trim().isNotEmpty == true
          ? note.memberId!.trim()
          : note.memberEmail?.trim().isNotEmpty == true
              ? note.memberEmail!.trim()
              : note.memberName.trim();
      byMember.putIfAbsent(key, () => []).add(note);
    }

    final latestByMember = <SoapNote>[];
    final signals = <_MemberSignal>[];
    var highRiskCount = 0;
    var followUpCount = 0;
    var painSum = 0;
    var painCount = 0;

    for (final memberNotes in byMember.values) {
      memberNotes.sort((a, b) => b.date.compareTo(a.date));
      final latest = memberNotes.first;
      latestByMember.add(latest);
      final previous = memberNotes.length > 1 ? memberNotes[1] : null;
      final pain = latest.painNow ?? latest.painWorst;
      final previousPain = previous?.painNow ?? previous?.painWorst;
      final followUpDue = _needsFollowUp(latest, now);
      final highRisk = latest.riskLevel == 'high' || (pain ?? 0) >= 8;
      final painUp =
          pain != null && previousPain != null && pain > previousPain;

      if (highRisk) highRiskCount += 1;
      if (followUpDue) followUpCount += 1;
      if (pain != null) {
        painSum += pain;
        painCount += 1;
      }

      if (followUpDue || highRisk || painUp) {
        final color = highRisk
            ? AppleColors.red
            : followUpDue
                ? AppleColors.orange
                : AppleColors.blue;
        final reason = highRisk
            ? '고위험 또는 통증 ${pain ?? '-'}'
            : followUpDue
                ? '재평가 또는 장기 미작성'
                : '통증 상승 ${previousPain ?? '-'} → $pain';
        signals.add(
          _MemberSignal(
            name: latest.memberName,
            reason: reason,
            trailing: latest.completionPercent == 100
                ? '완료'
                : '${latest.completionPercent}%',
            color: color,
          ),
        );
      }
    }

    signals.sort((a, b) => a.sortWeight.compareTo(b.sortWeight));
    latestByMember.sort((a, b) => b.date.compareTo(a.date));

    return _TrainerSummaryData(
      todaySessions: sorted.where((note) => _isSameDay(note.date, now)).length,
      memberCount: byMember.length,
      highRiskCount: highRiskCount,
      followUpCount: followUpCount,
      draftCount: sorted.where((note) => note.completionPercent < 100).length,
      averagePain: painCount == 0 ? 0 : painSum / painCount,
      latestNotes: sorted.take(6).toList(),
      attentionMembers: signals.take(6).toList(),
      trendPoints: latestByMember
          .take(7)
          .toList()
          .reversed
          .map(
            (note) => _TrendPoint(
              label: DateFormat('M.d').format(note.date),
              pain: (note.painNow ?? note.painWorst ?? 0).toDouble(),
              completion: note.completionPercent.toDouble(),
            ),
          )
          .toList(),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _needsFollowUp(SoapNote note, DateTime now) {
    final followUp = note.followUpDate;
    if (followUp != null && !followUp.isAfter(now)) return true;
    return now.difference(note.date).inDays >= 14;
  }
}

class _MetricItem {
  const _MetricItem({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
}

class _Priority {
  const _Priority({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

class _MemberSignal {
  const _MemberSignal({
    required this.name,
    required this.reason,
    required this.trailing,
    required this.color,
  });

  final String name;
  final String reason;
  final String trailing;
  final Color color;

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim().characters.first;

  int get sortWeight {
    if (color == AppleColors.red) return 0;
    if (color == AppleColors.orange) return 1;
    return 2;
  }
}

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.pain,
    required this.completion,
  });

  final String label;
  final double pain;
  final double completion;
}
