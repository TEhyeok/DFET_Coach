import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    // Premium Dark Theme Colors
    const bgGradientStart = Color(0xFF1A1A2E);
    const bgGradientEnd = Color(0xFF16213E);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgGradientStart, bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isIOS),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildGuideCard(
                      context,
                      title: "홈 대시보드",
                      icon: Icons.dashboard_rounded,
                      content: "대시보드에서는 오늘의 운동 요약과 웰니스 점수를 확인할 수 있습니다.\n\n"
                          "• 웰니스 점수: 운동, 식단, 수면 데이터를 종합하여 산출된 건강 점수입니다.\n"
                          "• 오늘의 활동: 오늘 수행해야 할 운동과 식단 목표를 한눈에 볼 수 있습니다.",
                    ),
                    const SizedBox(height: 16),
                    _buildGuideCard(
                      context,
                      title: "체형 분석 (Posture)",
                      icon: Icons.accessibility_new_rounded,
                      content: "AI를 이용해 체형 불균형을 분석합니다.\n\n"
                          "1. '촬영하기' 버튼을 누르세요.\n"
                          "2. 전신이 나오도록 카메라 앞에 서주세요.\n"
                          "3. 정면과 측면 사진을 촬영하면 AI가 거북목, 골반 불균형 등을 분석해줍니다.",
                    ),
                    const SizedBox(height: 16),
                    _buildGuideCard(
                      context,
                      title: "리포트 (Reports)",
                      icon: Icons.bar_chart_rounded,
                      content: "주간/월간 건강 변화를 그래프로 확인하세요.\n\n"
                          "• 체중 변화: 체중과 골격근량의 변화 추이를 보여줍니다.\n"
                          "• 운동 수행률: 계획된 운동을 얼마나 달성했는지 확인해보세요.",
                    ),
                    const SizedBox(height: 16),
                    _buildGuideCard(
                      context,
                      title: "식단 관리",
                      icon: Icons.restaurant_menu_rounded,
                      content: "매끼 식사를 사진으로 기록하세요.\n\n"
                          "AI가 음식 사진을 분석하여 칼로리와 영양소를 자동으로 계산해줍니다. "
                          "식단 기록은 웰니스 점수에 반영됩니다.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isIOS) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.back : Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            "사용 가이드",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE94560).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFE94560)),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                content,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
