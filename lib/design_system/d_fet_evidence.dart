import 'package:flutter/material.dart';

import '../theme/d_fet_typography.dart';
import '../theme/motion_tokens.dart';
import '../theme/tokens.dart';
import 'd_fet_axis_glyph.dart';
import 'd_fet_axis_icon.dart';

enum DfetEvidenceTone { neutral, pending, restricted }

/// 출처·정책·처리 상태를 짧은 기술 라벨로 표시한다.
class DfetEvidenceLabel extends StatelessWidget {
  const DfetEvidenceLabel({
    super.key,
    required this.label,
    this.tone = DfetEvidenceTone.neutral,
  });

  final String label;
  final DfetEvidenceTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    final foreground = switch (tone) {
      DfetEvidenceTone.neutral => colors.textSecondary,
      DfetEvidenceTone.pending => colors.warning,
      DfetEvidenceTone.restricted => colors.danger,
    };
    final background = switch (tone) {
      DfetEvidenceTone.neutral => colors.bgSubtle,
      DfetEvidenceTone.pending => colors.warning.withValues(alpha: 0.11),
      DfetEvidenceTone.restricted => colors.danger.withValues(alpha: 0.10),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: foreground.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 10,
              decoration: BoxDecoration(
                color: foreground,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 검사값의 숫자·단위·준비 상태 표현을 한 곳에서 관리한다.
class DfetMetricValue extends StatelessWidget {
  const DfetMetricValue({
    super.key,
    this.value,
    this.unit,
    this.pendingLabel = '산정 준비 중',
    this.axis,
    this.compact = false,
  });

  final String? value;
  final String? unit;
  final String pendingLabel;
  final DfetAxis? axis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    final foreground = axis == null
        ? context.wellness.textPrimary
        : DfetAxisPalette.color(context, axis!);
    final valueStyle = DfetTypography.dataStyle(
      color: foreground,
      fontSize: compact ? 15 : 28,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: compact ? -0.2 : -0.8,
    );

    return Semantics(
      label:
          hasValue ? [value, unit].whereType<String>().join(' ') : pendingLabel,
      child: AnimatedSwitcher(
        duration: DfetMotion.quick,
        switchInCurve: DfetMotion.emphasized,
        child: hasValue
            ? Text.rich(
                key: ValueKey('$value|$unit'),
                TextSpan(
                  text: value,
                  style: valueStyle,
                  children: [
                    if (unit != null && unit!.isNotEmpty)
                      TextSpan(
                        text: '  $unit',
                        style: DfetTypography.dataStyle(
                          color: context.wellness.textSecondary,
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              )
            : Text(
                pendingLabel,
                key: ValueKey(pendingLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.wellness.textSecondary,
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// 리포트 화면의 축·제목·기준시점을 동일한 위계로 배치한다.
class DfetReportHeader extends StatelessWidget {
  const DfetReportHeader({
    super.key,
    required this.axis,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final DfetAxis? axis;
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion ? Duration.zero : DfetMotion.standard,
      curve: DfetMotion.emphasized,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: DfetTypography.dataStyle(
                    color: axis == null
                        ? context.wellness.primary
                        : DfetAxisPalette.color(context, axis!),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: DfetTypography.displayStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.24,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          if (axis == null)
            const _IntegratedAxisMark()
          else
            DfetAxisAssetIcon(axis: axis!, size: 48),
        ],
      ),
    );
  }
}

class _IntegratedAxisMark extends StatelessWidget {
  const _IntegratedAxisMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '운동 식단 장 혈액 4축 통합',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 48,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: const [
              DfetAxisAssetIcon(axis: DfetAxis.motion, size: 22),
              DfetAxisAssetIcon(axis: DfetAxis.nutrition, size: 22),
              DfetAxisAssetIcon(axis: DfetAxis.gut, size: 22),
              DfetAxisAssetIcon(axis: DfetAxis.blood, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// 데이터 출처·완성도·정책 버전을 펼쳐 볼 수 있는 공통 근거 리본.
class DfetEvidenceRibbon extends StatefulWidget {
  const DfetEvidenceRibbon({
    super.key,
    required this.source,
    required this.coverage,
    required this.policyVersion,
    required this.detail,
    this.tone = DfetEvidenceTone.neutral,
  });

  final String source;
  final String coverage;
  final String? policyVersion;
  final String detail;
  final DfetEvidenceTone tone;

  @override
  State<DfetEvidenceRibbon> createState() => _DfetEvidenceRibbonState();
}

class _DfetEvidenceRibbonState extends State<DfetEvidenceRibbon>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.wellness;
    final policyLabel =
        widget.policyVersion == null ? '정책 미승인' : '정책 ${widget.policyVersion}';
    final policyTone =
        widget.policyVersion == null ? DfetEvidenceTone.pending : widget.tone;

    return Material(
      color: colors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Semantics(
          button: true,
          expanded: _expanded,
          label: '데이터 근거 ${_expanded ? '접기' : '펼치기'}',
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 28,
                      color: widget.tone == DfetEvidenceTone.restricted
                          ? colors.danger
                          : colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EVIDENCE / DATA PROVENANCE',
                            style: DfetTypography.dataStyle(
                              color: colors.textTertiary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '판정 근거와 데이터 상태',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.125 : 0,
                      duration: DfetMotion.quick,
                      child: Text(
                        '+',
                        style: DfetTypography.dataStyle(
                          color: colors.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    DfetEvidenceLabel(label: widget.source),
                    DfetEvidenceLabel(
                      label: widget.coverage,
                      tone: widget.tone,
                    ),
                    DfetEvidenceLabel(
                      label: policyLabel,
                      tone: policyTone,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: DfetMotion.standard,
                  curve: DfetMotion.emphasized,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.only(top: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: colors.borderSubtle),
                              ),
                            ),
                            child: Text(
                              widget.detail,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                height: 1.55,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
