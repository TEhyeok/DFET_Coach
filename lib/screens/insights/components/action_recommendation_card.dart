import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../design_system/d_fet_axis_glyph.dart';
import '../../../design_system/d_fet_axis_icon.dart';
import '../../../models/clinical_reports.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/app_card.dart';

class ActionRecommendationCard extends StatefulWidget {
  const ActionRecommendationCard({super.key, required this.insight});

  final HealthInsight insight;

  @override
  State<ActionRecommendationCard> createState() =>
      _ActionRecommendationCardState();
}

class _ActionRecommendationCardState extends State<ActionRecommendationCard> {
  bool _completed = false;

  String get _storageKey => 'clinical_action_completed_${widget.insight.id}';

  @override
  void initState() {
    super.initState();
    _loadCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.insight.action;
    if (action == null) return const SizedBox.shrink();
    final title = action['title']?.toString() ?? '생활관리 제안';
    final description = action['description']?.toString() ?? '';
    final duration = action['duration']?.toString();
    final impact = action['impact']?.toString();
    final checkIn = action['checkIn']?.toString();
    final ctaLabel = action['ctaLabel']?.toString() ?? '오늘 실천 시작';
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: Column(
          key: ValueKey(_completed),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _completed
                        ? context.wellness.success.withValues(alpha: 0.13)
                        : context.wellness.accentSubtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _completed ? Icons.check_rounded : Icons.bolt_rounded,
                    color: _completed
                        ? context.wellness.success
                        : context.wellness.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _completed ? '오늘의 한 걸음 완료' : '오늘의 한 가지',
                        style: TextStyle(
                          color: _completed
                              ? context.wellness.success
                              : context.wellness.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: TextStyle(
                          color: context.wellness.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _completed
                    ? '좋아요. 작은 실천을 완료 상태로 표시했어요. 다음 확인 때 데이터 흐름과 함께 살펴보세요.'
                    : description,
                style: TextStyle(
                  color: context.wellness.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
            if (impact != null) ...[
              const SizedBox(height: 12),
              _AxisImpactChip(label: impact),
            ],
            if (!_completed &&
                [duration, checkIn].any((value) => value != null)) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (duration != null)
                    _ActionChip(icon: Icons.timer_outlined, label: duration),
                  if (checkIn != null)
                    _ActionChip(
                        icon: Icons.event_available_outlined, label: checkIn),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _completed
                  ? OutlinedButton.icon(
                      onPressed: _toggleCompleted,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('완료 취소'),
                    )
                  : FilledButton.icon(
                      onPressed: _toggleCompleted,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(ctaLabel),
                    ),
            ),
            if (!_completed) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '완료 표시는 의료 기록이나 임상 판정에 반영되지 않습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wellness.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _completed = preferences.getBool(_storageKey) ?? false);
  }

  Future<void> _toggleCompleted() async {
    HapticFeedback.mediumImpact();
    final nextValue = !_completed;
    setState(() => _completed = nextValue);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_storageKey, nextValue);
  }
}

class _AxisImpactChip extends StatelessWidget {
  const _AxisImpactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final axes = _axesForLabel(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.wellness.bgSubtle,
        borderRadius: WellnessRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < axes.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            DfetAxisAssetIcon(axis: axes[index], size: 17),
          ],
          if (axes.isNotEmpty) const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.wellness.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static List<DfetAxis> _axesForLabel(String label) => [
        if (label.contains('운동')) DfetAxis.motion,
        if (label.contains('식단')) DfetAxis.nutrition,
        if (label.contains('장')) DfetAxis.gut,
        if (label.contains('혈액')) DfetAxis.blood,
      ];
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.wellness.bgSubtle,
        borderRadius: WellnessRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.wellness.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.wellness.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
