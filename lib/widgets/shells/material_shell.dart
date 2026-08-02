import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/dashboard.dart';
import '../../screens/meals.dart';
import '../../screens/workouts.dart';
import '../../screens/reports.dart';
import '../../screens/tickets.dart';
import '../../screens/settings_screen.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';

/// Material 스타일 Shell (Android용 백업)
class MaterialShell extends ConsumerWidget {
  const MaterialShell({super.key});

  static const List<Widget> _screens = [
    DashboardScreen(),
    MealsScreen(),
    WorkoutsScreen(),
    ReportsScreen(),
    TicketsScreen(),
  ];

  static const List<String> _titles = [
    'D-FET',
    '식단',
    '운동',
    '리포트',
    '요청',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);

    return Scaffold(
      backgroundColor: PremiumColors.backgroundStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _titles[currentIndex],
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PremiumColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            tooltip: '알림',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림 기능은 준비 중입니다')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: '설정',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _screens[currentIndex]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: PremiumColors.cardBackground,
          indicatorColor: PremiumColors.primary.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              );
            }
            return GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white70,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: PremiumColors.primary);
            }
            return const IconThemeData(color: Colors.white70);
          }),
        ),
        child: NavigationBar(
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
            NavigationDestination(icon: Icon(Icons.restaurant), label: '식단'),
            NavigationDestination(
                icon: Icon(Icons.fitness_center), label: '운동'),
            NavigationDestination(
                icon: Icon(Icons.assessment_outlined), label: '리포트'),
            NavigationDestination(icon: Icon(Icons.support_agent), label: '요청'),
          ],
          selectedIndex: currentIndex,
          onDestinationSelected: (i) {
            ref.read(currentTabIndexProvider.notifier).state = i;
          },
        ),
      ),
    );
  }
}
