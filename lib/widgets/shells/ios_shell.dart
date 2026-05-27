import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/dashboard.dart';
import '../../screens/ios_profile_screen.dart';
import '../../screens/record_hub_screen.dart';
import '../../screens/reports.dart';
import '../../screens/community/community_screen.dart';
import '../../screens/settings_screen.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../utils/responsive_layout.dart';
import 'ios_destination.dart';

/// iOS 스타일 Shell (CupertinoTabScaffold)
class IOSShell extends ConsumerStatefulWidget {
  const IOSShell({super.key});

  @override
  ConsumerState<IOSShell> createState() => _IOSShellState();
}

class _IOSShellState extends ConsumerState<IOSShell> {
  static const List<IOSDestination> _destinations = IOSDestination.values;

  late CupertinoTabController _tabController;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    _destinations.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider로부터 현재 탭 인덱스 감지
    final tabIndex = ref.watch(currentTabIndexProvider);

    if (ResponsiveLayout.isTablet(context)) {
      return _buildTabletShell(context, tabIndex);
    }

    // Provider 값이 변경되면 탭 컨트롤러 업데이트
    if (_tabController.index != tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_tabController.index != tabIndex && mounted) {
          _tabController.index = tabIndex;
        }
      });
    }

    return CupertinoTabScaffold(
      controller: _tabController,
      backgroundColor: Colors.black, // Pure black background behind tabs
      tabBar: CupertinoTabBar(
        backgroundColor:
            PremiumColors.cardBackground.withOpacity(0.8), // Glassmorphism
        activeColor: PremiumColors.primary, // Neon Pink
        inactiveColor: Colors.white60,
        height: 60,
        border: const Border(
          top: BorderSide(color: Colors.white10, width: 0.5),
        ),
        iconSize: 28,
        onTap: (index) {
          if (_tabController.index == index) {
            // 이미 선택된 탭을 다시 누르면 네비게이션 스택 초기화 (첫 화면으로 이동)
            _navigatorKeys[index]
                .currentState
                ?.popUntil((route) => route.isFirst);
          } else {
            // 다른 탭을 누르면 탭 전환
            ref.read(currentTabIndexProvider.notifier).state = index;
          }
        },
        items: _destinations
            .map(
              (destination) => BottomNavigationBarItem(
                icon: Icon(destination.icon),
                activeIcon: Icon(destination.activeIcon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
      tabBuilder: (context, index) {
        final screen = _screenForIndex(index);
        final title = _destinations[index].title;

        return CupertinoTabView(
          navigatorKey: _navigatorKeys[index],
          builder: (context) {
            return CupertinoPageScaffold(
              backgroundColor: PremiumColors.backgroundStart,
              navigationBar: CupertinoNavigationBar(
                backgroundColor: PremiumColors.backgroundStart.withOpacity(0.8),
                border: const Border(
                  bottom: BorderSide(
                    color: Colors.white10,
                    width: 0.5,
                  ),
                ),
                middle: Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          const Icon(CupertinoIcons.bell,
                              size: 24, color: Colors.white),
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
                      onPressed: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            content: const Text('알림 기능은 준비 중입니다'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('확인'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.settings,
                          size: 24, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              child: SafeArea(child: screen),
            );
          },
        );
      },
    );
  }

  Widget _buildTabletShell(BuildContext context, int tabIndex) {
    final selectedIndex = tabIndex.clamp(0, _destinations.length - 1).toInt();
    final destination = _destinations[selectedIndex];

    return CupertinoPageScaffold(
      backgroundColor: PremiumColors.backgroundStart,
      child: Row(
        children: [
          _buildSidebar(context, selectedIndex),
          Expanded(
            child: CupertinoPageScaffold(
              backgroundColor: PremiumColors.backgroundStart,
              navigationBar: CupertinoNavigationBar(
                automaticallyImplyLeading: false,
                backgroundColor:
                    PremiumColors.backgroundStart.withOpacity(0.88),
                border: const Border(
                  bottom: BorderSide(color: Colors.white10, width: 0.5),
                ),
                middle: Text(
                  destination.title,
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
                trailing: _buildToolbarActions(context),
              ),
              child: SafeArea(
                bottom: false,
                child: _screenForIndex(selectedIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, int selectedIndex) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: PremiumColors.cardBackground.withOpacity(0.72),
        border: const Border(
          right: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'D-FET',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              for (var index = 0; index < _destinations.length; index++) ...[
                _buildSidebarItem(index, selectedIndex),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.settings,
                          size: 20, color: Colors.white70),
                      const SizedBox(width: 10),
                      Text(
                        '설정',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, int selectedIndex) {
    final destination = _destinations[index];
    final isSelected = index == selectedIndex;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        ref.read(currentTabIndexProvider.notifier).state = index;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? PremiumColors.primary.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? PremiumColors.primary.withOpacity(0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? destination.activeIcon : destination.icon,
              size: 22,
              color: isSelected ? PremiumColors.primary : Colors.white54,
            ),
            const SizedBox(width: 12),
            Text(
              destination.label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              const Icon(CupertinoIcons.bell, size: 24, color: Colors.white),
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
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                content: const Text('알림 기능은 준비 중입니다'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('확인'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings,
              size: 24, color: Colors.white),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _screenForIndex(int index) {
    final destination =
        _destinations[index.clamp(0, _destinations.length - 1).toInt()];

    switch (destination) {
      case IOSDestination.home:
        return const DashboardScreen();
      case IOSDestination.record:
        return const RecordHubScreen();
      case IOSDestination.coaching:
        return const ReportsScreen();
      case IOSDestination.community:
        return const CommunityScreen();
      case IOSDestination.profile:
        return const IOSProfileScreen();
    }
  }
}
