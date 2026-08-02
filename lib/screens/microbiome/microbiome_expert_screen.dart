import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/tokens.dart';
import 'components/microbiome_category_card.dart';

/// 전문가용 상세 분석 화면 (Soft Wellness · 다크 대응)
///
/// 일반 소비자용 리포트([MicrobiomeScreen])에서 분리한 원시 16S rRNA(V3-V4)
/// 분석 결과를 표시한다. 라우트로 push 되므로 자체 Scaffold/AppBar 를 가진다.
/// 표시 항목:
///  1) 베타 다양성 PCoA 산점도 (Bray-Curtis)
///  2) 알파 다양성 상세 (Shannon/Simpson/Chao1/Observed)
///  3) Genus 수준 상대적 풍부도 (가로 바)
///  4) 계통학적 유사도 (UniFrac weighted/unweighted)
///  5) 분석 메타데이터 푸터
class MicrobiomeExpertScreen extends ConsumerWidget {
  const MicrobiomeExpertScreen({super.key});

  // ---------------------------------------------------------------------------
  // Mock Data
  // ---------------------------------------------------------------------------

  /// PCoA 좌표 (PC1, PC2) — 또래 샘플 군집 + 내 샘플.
  /// isMe 가 true 인 점이 '나(me)'.
  static const List<_PcoaPoint> _pcoaPoints = [
    _PcoaPoint(0.12, 0.20),
    _PcoaPoint(0.18, 0.14),
    _PcoaPoint(0.24, 0.28),
    _PcoaPoint(0.31, 0.18),
    _PcoaPoint(0.28, 0.34),
    _PcoaPoint(0.35, 0.26),
    _PcoaPoint(0.42, 0.31),
    _PcoaPoint(0.21, 0.41),
    _PcoaPoint(0.38, 0.45),
    _PcoaPoint(0.48, 0.38),
    _PcoaPoint(0.45, 0.52),
    _PcoaPoint(0.33, 0.30, isMe: true), // 나(me)
  ];

  /// 알파 다양성 상세 지표.
  static const List<_AlphaMetric> _alphaMetrics = [
    _AlphaMetric('Shannon', '2.4', '샘플 내 다양성'),
    _AlphaMetric('Simpson', '0.82', '우점도 보정'),
    _AlphaMetric('Chao1', '312', '추정 풍부도'),
    _AlphaMetric('Observed OTUs', '248', '관측 OTU 수'),
  ];

  /// Genus 수준 상대적 풍부도 (%).
  static const List<_Genus> _genera = [
    _Genus('Bacteroides', 22),
    _Genus('Prevotella', 15),
    _Genus('Faecalibacterium', 11),
    _Genus('Bifidobacterium', 8),
    _Genus('Roseburia', 6),
    _Genus('Akkermansia', 5),
    _Genus('Eubacterium', 4),
    _Genus('Others', 29),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wellness;
    return Scaffold(
      backgroundColor: w.bgRoot,
      appBar: AppBar(
        backgroundColor: w.bgRoot,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: w.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          '전문가 상세 분석',
          style: TextStyle(
            color: w.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPcoaSection(context),
            _buildAlphaSection(context),
            _buildGenusSection(context),
            _buildPhyloSection(context),
            const SizedBox(height: 4),
            _buildMetaFooter(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1) 베타 다양성 — PCoA 산점도
  // ---------------------------------------------------------------------------
  Widget _buildPcoaSection(BuildContext context) {
    final w = context.wellness;
    return MicrobiomeCategoryCard(
      title: '베타 다양성 (PCoA)',
      icon: Icons.scatter_plot_rounded,
      iconColor: w.primary,
      children: [
        SizedBox(
          height: 220,
          child: ScatterChart(
            ScatterChartData(
              minX: 0,
              maxX: 0.6,
              minY: 0,
              maxY: 0.6,
              scatterSpots: [
                for (final p in _pcoaPoints)
                  ScatterSpot(
                    p.pc1,
                    p.pc2,
                    dotPainter: FlDotCirclePainter(
                      radius: p.isMe ? 9 : 5,
                      color: p.isMe ? w.primary : w.textTertiary,
                      strokeWidth: p.isMe ? 2 : 0,
                      strokeColor: w.bgCard,
                    ),
                  ),
              ],
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: w.borderSubtle, strokeWidth: 1),
                getDrawingVerticalLine: (_) =>
                    FlLine(color: w.borderSubtle, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  axisNameSize: 18,
                  axisNameWidget: Text(
                    'PC1',
                    style: TextStyle(color: w.textTertiary, fontSize: 10),
                  ),
                  sideTitles: const SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  axisNameSize: 18,
                  axisNameWidget: Text(
                    'PC2',
                    style: TextStyle(color: w.textTertiary, fontSize: 10),
                  ),
                  sideTitles: const SideTitles(showTitles: false),
                ),
              ),
              scatterTouchData: ScatterTouchData(enabled: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildDot(w.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text('나(me)',
                  style: TextStyle(color: w.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 16),
            _buildDot(w.textTertiary),
            const SizedBox(width: 6),
            Flexible(
              child: Text('또래 샘플',
                  style: TextStyle(color: w.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Bray-Curtis distance · 또래 샘플 군집',
          style: TextStyle(color: w.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ---------------------------------------------------------------------------
  // 2) 알파 다양성 상세 — 2열 메트릭 그리드
  // ---------------------------------------------------------------------------
  Widget _buildAlphaSection(BuildContext context) {
    final w = context.wellness;
    return MicrobiomeCategoryCard(
      title: '알파 다양성 상세',
      icon: Icons.bubble_chart_rounded,
      iconColor: w.primaryLight,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            for (final m in _alphaMetrics) _buildAlphaCell(context, m),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '샘플 내 다양성 지표 (rarefied)',
          style: TextStyle(color: w.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAlphaCell(BuildContext context, _AlphaMetric m) {
    final w = context.wellness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: w.bgSubtle,
        borderRadius: WellnessRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            m.label,
            style: TextStyle(
              color: w.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            m.value,
            style: TextStyle(
              color: w.primary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            m.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: w.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3) Genus 수준 상대적 풍부도 — 가로 바 리스트
  // ---------------------------------------------------------------------------
  Widget _buildGenusSection(BuildContext context) {
    final w = context.wellness;
    return MicrobiomeCategoryCard(
      title: '상대적 풍부도 (Genus)',
      icon: Icons.bar_chart_rounded,
      iconColor: w.accent,
      children: [
        for (int i = 0; i < _genera.length; i++) ...[
          _buildGenusBar(context, _genera[i]),
          if (i != _genera.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 14),
        Text(
          '속(Genus) 수준 상위 분류군',
          style: TextStyle(color: w.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildGenusBar(BuildContext context, _Genus g) {
    final w = context.wellness;
    final isOthers = g.name == 'Others';
    final barColor = isOthers ? w.textTertiary : w.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              g.name,
              style: TextStyle(
                color: w.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontStyle: isOthers ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            Text(
              '${g.value}%',
              style: TextStyle(
                color: w.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final fullW = constraints.maxWidth;
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: w.bgSubtle,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                Container(
                  width: fullW * (g.value / 100.0),
                  height: 8,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4) 계통학적 유사도 — UniFrac 메트릭 카드
  // ---------------------------------------------------------------------------
  Widget _buildPhyloSection(BuildContext context) {
    final w = context.wellness;
    return MicrobiomeCategoryCard(
      title: '계통학적 유사도',
      icon: Icons.account_tree_rounded,
      iconColor: w.info,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildUniFracCell(
                  context,
                  label: 'UniFrac (weighted)',
                  value: '0.31',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUniFracCell(
                  context,
                  label: 'UniFrac (unweighted)',
                  value: '0.42',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '건강 참조 군집과의 계통학적 거리 (0에 가까울수록 유사)',
          style: TextStyle(color: w.textTertiary, fontSize: 11, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildUniFracCell(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final w = context.wellness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: w.bgSubtle,
        borderRadius: WellnessRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: w.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: w.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5) 메타데이터 푸터
  // ---------------------------------------------------------------------------
  Widget _buildMetaFooter(BuildContext context) {
    final w = context.wellness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: w.bgCard,
        borderRadius: WellnessRadius.card,
        boxShadow: WellnessShadows.soft,
      ),
      child: Row(
        children: [
          Icon(Icons.science_rounded, color: w.textTertiary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '분석법: 16S rRNA · 영역: V3-V4 · 플랫폼: Illumina MiSeq · 파이프라인: QIIME2',
              style: TextStyle(
                color: w.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mock data models
// ---------------------------------------------------------------------------

class _PcoaPoint {
  final double pc1;
  final double pc2;
  final bool isMe;
  const _PcoaPoint(this.pc1, this.pc2, {this.isMe = false});
}

class _AlphaMetric {
  final String label;
  final String value;
  final String caption;
  const _AlphaMetric(this.label, this.value, this.caption);
}

class _Genus {
  final String name;
  final int value;
  const _Genus(this.name, this.value);
}
