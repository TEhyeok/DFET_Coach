import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dfet_coach/theme/admin_theme.dart';

class ContentDashboardPage extends StatelessWidget {
  const ContentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '콘텐츠 관리',
            style: AdminTheme.displayLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '운동 및 식단 데이터베이스를 관리합니다.',
            style: AdminTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _ContentCard(
                title: '운동 DB',
                description: '운동 종목, 부위, 난이도 등 운동 데이터를 관리합니다.',
                icon: Icons.fitness_center,
                color: AdminColors.primary,
                onTap: () => context.go('/admin/content/workouts'),
              ),
              const SizedBox(width: 24),
              _ContentCard(
                title: '식단 DB',
                description: '음식 영양 정보 및 카테고리를 관리합니다.',
                icon: Icons.restaurant_menu,
                color: AdminColors.secondary,
                onTap: () => context.go('/admin/content/foods'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ContentCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AdminColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
