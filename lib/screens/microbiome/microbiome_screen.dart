import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/tokens.dart';
import 'components/microbiome_score_gauge.dart';
import 'components/microbiome_category_card.dart';
import 'microbiome_expert_screen.dart';

/// 장 건강 리포트 화면 (Soft Wellness 디자인)
///
/// 16S rRNA sequencing (V3-V4) 분석 결과를 일반 소비자용으로 재구성.
/// 4대 지표: 알파 다양성 / 상대적 풍부도 / 베타 다양성 / 계통학적 유사도.
/// - 어려운 지표는 쉬운 해석 + 정상범위 비교로 표현, 원시 수치는 작게 병기.
/// - 전문가용 상세(PCoA 산점도·계통수)는 '상세 보기'로 분리(추후 구현).
/// - 셸이 Scaffold/하단탭을 제공하므로 스크롤 본문만 반환.
class MicrobiomeScreen extends ConsumerWidget {
  const MicrobiomeScreen({super.key});

  // ---------------------------------------------------------------------------
  // Mock Data — 16S rRNA(V3-V4) 분석 결과 구조
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> _getMockData() {
    return {
      'analyzedAt': '2026.06.18',
      'method': '16S rRNA · V3–V4',
      // 알파 다양성 (샘플 내 다양성)
      'alpha': {
        'score': 82.0, // 0~100 정규화 점수
        'shannon': 2.4,
        'observedSpecies': 248,
        'percentile': 18, // 상위 %
        'level': '양호',
        // 정상범위 띠 위 내 위치(0~1)
        'rangeStart': 0.35,
        'rangeEnd': 0.75,
        'marker': 0.72,
      },
      // 상대적 풍부도 (Phylum 기준)
      'composition': [
        {'name': '후벽균 (Firmicutes)', 'short': '후벽균', 'value': 46.0},
        {'name': '의간균 (Bacteroidetes)', 'short': '의간균', 'value': 28.0},
        {'name': '방선균 (Actinobacteria)', 'short': '방선균', 'value': 14.0},
        {'name': '기타', 'short': '기타', 'value': 12.0},
      ],
      // 베타 다양성 (샘플 간 차이 → 또래 대비 해석)
      'beta': {
        'label': '비슷해요',
        'detail': '또래 군집 내 위치',
        'level': '양호',
      },
      // 계통학적 유사도
      'phylo': {
        'similarity': 87,
        'detail': 'UniFrac 기반',
      },
      'recommendation':
          '의간균이 또래보다 다소 낮아요. 식이섬유(채소·통곡물)와 발효식품을 늘리면 다양성 점수가 올라갈 수 있어요.',
    };
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = _getMockData();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, data),
          const SizedBox(height: 14),

          // 1) 알파 다양성 (메인 점수 + 정상범위 비교)
          _buildAlphaSection(context, data['alpha'] as Map<String, dynamic>),

          // 2) 상대적 풍부도 (Phylum 누적바)
          _buildCompositionSection(
              context, data['composition'] as List<dynamic>),

          // 3) 베타 다양성 + 계통학적 유사도 (비교 카드 2개)
          _buildComparisonRow(context, data),
          const SizedBox(height: 12),

          // 4) 맞춤 추천
          _buildRecommendation(context, data['recommendation'] as String),
          const SizedBox(height: 12),

          // 5) 전문가용 상세 보기 → MicrobiomeExpertScreen 라우트
          _buildExpertEntry(context),
          const SizedBox(height: 12),

          Text(
            '본 리포트는 의료 진단이 아니며, 참고용으로만 활용하십시오.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: context.wellness.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 헤더 (제목 + 분석법 메타)
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '장 건강 리포트',
                style: TextStyle(
                  color: context.wellness.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.wellness.primarySubtle,
                borderRadius: WellnessRadius.chip,
              ),
              child: Text(
                data['method']?.toString() ?? '',
                style: TextStyle(
                  color: context.wellness.primaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${data['analyzedAt']} 분석 · 장내미생물 시퀀싱 결과',
          style: TextStyle(
            color: context.wellness.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1) 알파 다양성 — 메인 점수 게이지 + 정상범위 띠
  // ---------------------------------------------------------------------------
  Widget _buildAlphaSection(BuildContext context, Map<String, dynamic> alpha) {
    final percentile = (alpha['percentile'] as num?)?.toInt() ?? 0;
    return MicrobiomeCategoryCard(
      title: '장내 생태계 다양성',
      icon: Icons.bubble_chart_rounded,
      iconColor: context.wellness.primary,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MicrobiomeScoreGauge(
              score: _safeToDouble(alpha['score']),
              size: 130,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '미생물이 다양하고 균형있게 살고 있어요.',
                    style: TextStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.wellness.primarySubtle,
                      borderRadius: WellnessRadius.chip,
                    ),
                    child: Text(
                      '또래 중 상위 $percentile%',
                      style: TextStyle(
                        color: context.wellness.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildRangeBar(
          context,
          start: _safeToDouble(alpha['rangeStart']),
          end: _safeToDouble(alpha['rangeEnd']),
          marker: _safeToDouble(alpha['marker']),
        ),
        const SizedBox(height: 8),
        Text(
          '알파 다양성 (Shannon ${alpha['shannon']} · 종 풍부도 ${alpha['observedSpecies']}종)',
          style: TextStyle(
            color: context.wellness.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// 정상범위 띠 위에 내 위치 마커를 표시하는 바
  Widget _buildRangeBar(
    BuildContext context, {
    required double start,
    required double end,
    required double marker,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('낮음',
                style: TextStyle(
                    color: context.wellness.textTertiary, fontSize: 10)),
            Text('정상 범위',
                style: TextStyle(
                    color: context.wellness.textSecondary, fontSize: 10)),
            Text('높음',
                style: TextStyle(
                    color: context.wellness.textTertiary, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.wellness.bgSubtle,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * start,
                    width: w * (end - start),
                    top: 3,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.wellness.primarySubtle,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (w * marker) - 7,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.wellness.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.wellness.bgCard, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2) 상대적 풍부도 — Phylum 가로 누적바 + 범례
  // ---------------------------------------------------------------------------
  static const List<Color> _compositionColors = [
    WellnessColors.primary,
    WellnessColors.primaryLight,
    WellnessColors.accent,
    WellnessColors.info,
    WellnessColors.borderSubtle,
  ];

  Widget _buildCompositionSection(
      BuildContext context, List<dynamic> composition) {
    return MicrobiomeCategoryCard(
      title: '내 장에 사는 미생물 구성',
      icon: Icons.donut_large_rounded,
      iconColor: context.wellness.primaryLight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (int i = 0; i < composition.length; i++)
                  Expanded(
                    flex: (_safeToDouble(
                                (composition[i] as Map)['value']) *
                            10)
                        .round(),
                    child: Container(
                      color: _compositionColors[i % _compositionColors.length],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (int i = 0; i < composition.length; i++)
              _buildLegendItem(
                context,
                _compositionColors[i % _compositionColors.length],
                (composition[i] as Map)['short']?.toString() ?? '',
                _safeToDouble((composition[i] as Map)['value']),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '상대적 풍부도 (Phylum 기준)',
          style:
              TextStyle(color: context.wellness.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLegendItem(
      BuildContext context, Color color, String name, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          '$name ${value.toInt()}%',
          style: TextStyle(
            color: context.wellness.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3) 베타 다양성 + 계통학적 유사도 — 비교 카드 2개
  // ---------------------------------------------------------------------------
  Widget _buildComparisonRow(BuildContext context, Map<String, dynamic> data) {
    final beta = data['beta'] as Map<String, dynamic>;
    final phylo = data['phylo'] as Map<String, dynamic>;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildCompareCard(
              context,
              label: '또래 평균과 비교',
              value: beta['label']?.toString() ?? '-',
              sub: '베타 다양성 · ${beta['detail']}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompareCard(
              context,
              label: '건강한 장과 닮은 정도',
              value: '${phylo['similarity']}%',
              sub: '계통학적 유사도 · ${phylo['detail']}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareCard(
    BuildContext context, {
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.wellness.bgCard,
        borderRadius: WellnessRadius.cardLarge,
        boxShadow: WellnessShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.wellness.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: context.wellness.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sub,
            style: TextStyle(
              color: context.wellness.textTertiary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4) 맞춤 추천
  // ---------------------------------------------------------------------------
  Widget _buildRecommendation(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.wellness.accentSubtle,
        borderRadius: WellnessRadius.cardLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded,
                  color: context.wellness.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                '맞춤 추천',
                style: TextStyle(
                  color: context.wellness.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: context.wellness.textPrimary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5) 전문가용 상세 보기 → MicrobiomeExpertScreen 라우트로 push
  // ---------------------------------------------------------------------------
  Widget _buildExpertEntry(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MicrobiomeExpertScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.wellness.bgCard,
          borderRadius: WellnessRadius.card,
          boxShadow: WellnessShadows.soft,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '전문가용 상세 분석 보기',
              style: TextStyle(
                color: context.wellness.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.wellness.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
