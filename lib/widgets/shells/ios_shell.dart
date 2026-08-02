import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/dashboard.dart';
import '../../screens/ios_profile_screen.dart';
import '../../screens/record_hub_screen.dart';
import '../../screens/report_hub_screen.dart';
import '../../screens/reports.dart';
import '../../screens/community/community_screen.dart';
import '../../screens/microbiome/microbiome_screen.dart';
import '../../screens/settings_screen.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../utils/responsive_layout.dart';
import 'ios_destination.dart';

/// 2026 개편: 하단 탭을 4개로 고정 (홈 · 기록 · 리포트 · 내 정보).
/// 리포트 탭이 careType에 따라 내용을 분기하므로 탭 개수는 항상 동일.
/// (커뮤니티는 홈/내 정보 진입, 코칭·장건강 통계는 리포트로 통합)
List<IOSDestination> destinationsForCareType(CareType careType) {
  return const [
    IOSDestination.home,
    IOSDestination.record,
    IOSDestination.report,
    IOSDestination.profile,
  ];
}

/// iOS 스타일 Shell (CupertinoTabScaffold)
class IOSShell extends ConsumerStatefulWidget {
  const IOSShell({super.key});

  @override
  ConsumerState<IOSShell> createState() => _IOSShellState();
}

class _IOSShellState extends ConsumerState<IOSShell> {
  // careType에 따라 build 시점에 결정되는 동적 탭 목록
  List<IOSDestination> _destinations = destinationsForCareType(
    UserCareType.fitness,
  );

  late CupertinoTabController _tabController;
  // 최대 탭 수(both = 6)만큼 미리 키를 생성해 두고 인덱스로 사용
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    6,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
  }

  /// 현재 사용자(로그인/게스트)의 케어 유형을 통합해서 읽는다.
  CareType _resolveCareType() {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile != null) return profile.careType;
    return ref.watch(guestCareTypeProvider);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // careType에 따라 탭 구성 결정
    _destinations = destinationsForCareType(_resolveCareType());

    // Provider로부터 현재 탭 인덱스 감지 (범위 보정)
    final rawIndex = ref.watch(currentTabIndexProvider);
    final tabIndex = rawIndex.clamp(0, _destinations.length - 1).toInt();

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
      backgroundColor: context.wellness.bgRoot,
      tabBar: CupertinoTabBar(
        backgroundColor: context.wellness.bgCard.withValues(alpha: 0.95),
        activeColor: context.wellness.primary,
        inactiveColor: context.wellness.textTertiary,
        height: 60,
        border: Border(
          top: BorderSide(color: context.wellness.borderSubtle, width: 0.5),
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
              backgroundColor: context.wellness.bgRoot,
              navigationBar: CupertinoNavigationBar(
                backgroundColor: context.wellness.bgRoot.withValues(alpha: 0.9),
                border: Border(
                  bottom: BorderSide(
                    color: context.wellness.borderSubtle,
                    width: 0.5,
                  ),
                ),
                middle: _navTitle(context, title),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Icon(CupertinoIcons.bell,
                              size: 24, color: context.wellness.textPrimary),
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
                      child: Icon(CupertinoIcons.settings,
                          size: 24, color: context.wellness.textPrimary),
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
                    context.wellness.bgRoot.withValues(alpha: 0.88),
                border: Border(
                  bottom: BorderSide(
                      color: context.wellness.borderSubtle, width: 0.5),
                ),
                middle: Text(
                  destination.title,
                  style:
                      GoogleFonts.outfit(color: context.wellness.textPrimary),
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
        color: context.wellness.bgCard.withValues(alpha: 0.72),
        border: Border(
          right: BorderSide(color: context.wellness.borderSubtle, width: 0.5),
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
                    color: context.wellness.textPrimary,
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
                    color: context.wellness.bgSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.wellness.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.settings,
                          size: 20, color: context.wellness.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        '설정',
                        style: GoogleFonts.outfit(
                          color: context.wellness.textSecondary,
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
              ? PremiumColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? PremiumColors.primary.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? destination.activeIcon : destination.icon,
              size: 22,
              color: isSelected
                  ? PremiumColors.primary
                  : context.wellness.textTertiary,
            ),
            const SizedBox(width: 12),
            Text(
              destination.label,
              style: GoogleFonts.outfit(
                color: isSelected
                    ? context.wellness.textPrimary
                    : context.wellness.textTertiary,
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
              Icon(CupertinoIcons.bell,
                  size: 24, color: context.wellness.textPrimary),
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
          child: Icon(CupertinoIcons.settings,
              size: 24, color: context.wellness.textPrimary),
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

  /// 네비게이션 바 타이틀. 홈 탭은 로고 마크, 나머지는 텍스트.
  Widget _navTitle(BuildContext context, String title) {
    if (title == 'D-FET') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      // 다크: 흰색 로고(D-FET_logo.png), 라이트: 네이비 로고(D-FET_logo_2.png)
      return Image.asset(
        isDark
            ? 'assets/image/D-FET_logo.png'
            : 'assets/image/D-FET_logo_2.png',
        height: 26,
        fit: BoxFit.contain,
      );
    }
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: context.wellness.textPrimary,
        fontWeight: FontWeight.w600,
      ),
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
      case IOSDestination.report:
        return const ReportHubScreen();
      case IOSDestination.microbiome:
        return const MicrobiomeScreen();
      case IOSDestination.coaching:
        return const ReportsScreen();
      case IOSDestination.community:
        return const CommunityScreen();
      case IOSDestination.profile:
        return const IOSProfileScreen();
    }
  }
}
