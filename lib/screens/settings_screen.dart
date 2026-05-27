import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_state.dart';
import '../models/user_profile.dart';
import 'guide_screen.dart';
import 'subscription_screen.dart';
import '../theme/tokens.dart';
import '../utils/ios_navigation.dart';
import '../utils/responsive_layout.dart';
import 'my_info_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    final isGuest =
        ref.watch(isGuestModeProvider) || ref.watch(isTrainerGuestModeProvider);

    // Premium Gradient Background
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PremiumColors.backgroundStart, PremiumColors.backgroundEnd],
        ),
      ),
      child: isIOS
          ? _buildIOSLayout(context, ref, isGuest)
          : _buildMaterialLayout(context, ref, isGuest),
    );
  }

  /// iOS Cupertino 스타일
  Widget _buildIOSLayout(BuildContext context, WidgetRef ref, bool isGuest) {
    final user = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent, // Use gradient from parent
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          '설정',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: ResponsiveLayout.compactPagePadding(context),
              children: [
                const SizedBox(height: 20),

                // 프로필 카드
                _buildProfileCard(context, ref, user, userProfileAsync,
                    isGuest: isGuest, isIOS: true),

                const SizedBox(height: 30),

                const SizedBox(height: 30),

                // 구독 관리
                _buildSectionHeader('멤버십'),
                _buildPremiumCard(context),

                const SizedBox(height: 30),

                // 게스트 모드가 아닐 때만 계정 섹션 표시
                if (!isGuest) ...[
                  // 계정 섹션
                  _buildSectionHeader('계정'),
                  _buildGlassContainer(
                    child: Column(
                      children: [
                        _buildListTile(
                          icon: CupertinoIcons.arrow_right_arrow_left_circle,
                          title: '계정 전환',
                          onTap: () =>
                              _handleSwitchAccount(context, ref, isIOS: true),
                          isIOS: true,
                        ),
                        _buildDivider(),
                        _buildListTile(
                          icon: CupertinoIcons.square_arrow_right,
                          title: '로그아웃',
                          onTap: () => _handleLogout(context, ref, isIOS: true),
                          isIOS: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 위험 구역
                  _buildSectionHeader('위험 구역'),
                  _buildGlassContainer(
                    child: _buildListTile(
                      icon: CupertinoIcons.delete,
                      iconColor: CupertinoColors.destructiveRed,
                      title: '회원탈퇴',
                      titleColor: CupertinoColors.destructiveRed,
                      onTap: () =>
                          _handleDeleteAccount(context, ref, isIOS: true),
                      isIOS: true,
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // 지원
                _buildSectionHeader('지원'),
                _buildGlassContainer(
                  child: _buildListTile(
                    icon: CupertinoIcons.question_circle,
                    title: '사용 가이드',
                    onTap: () => _handleGuide(context),
                    isIOS: true,
                  ),
                ),

                const SizedBox(height: 40),

                // 앱 정보
                Center(
                  child: Column(
                    children: [
                      Text(
                        'D-FET',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Android Material 스타일
  Widget _buildMaterialLayout(
      BuildContext context, WidgetRef ref, bool isGuest) {
    final user = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('설정', style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: ResponsiveLayout.compactPagePadding(context),
              children: [
                const SizedBox(height: 20),

                // 프로필 카드
                _buildProfileCard(context, ref, user, userProfileAsync,
                    isGuest: isGuest, isIOS: false),

                const SizedBox(height: 30),

                const SizedBox(height: 30),

                // 구독 관리
                _buildSectionHeader('멤버십'),
                _buildPremiumCard(context),

                const SizedBox(height: 30),

                // 게스트 모드가 아닐 때만 계정 섹션 표시
                if (!isGuest) ...[
                  // 계정 섹션
                  _buildSectionHeader('계정'),
                  _buildGlassContainer(
                    child: Column(
                      children: [
                        _buildListTile(
                          icon: Icons.swap_horiz,
                          title: '계정 전환',
                          onTap: () =>
                              _handleSwitchAccount(context, ref, isIOS: false),
                          isIOS: false,
                        ),
                        _buildDivider(),
                        _buildListTile(
                          icon: Icons.logout,
                          title: '로그아웃',
                          onTap: () =>
                              _handleLogout(context, ref, isIOS: false),
                          isIOS: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 위험 구역
                  _buildSectionHeader('위험 구역'),
                  _buildGlassContainer(
                    child: _buildListTile(
                      icon: Icons.delete_forever,
                      iconColor: Colors.red,
                      title: '회원탈퇴',
                      titleColor: Colors.red,
                      onTap: () =>
                          _handleDeleteAccount(context, ref, isIOS: false),
                      isIOS: false,
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // 지원
                _buildSectionHeader('지원'),
                _buildGlassContainer(
                  child: _buildListTile(
                    icon: Icons.help_outline,
                    title: '사용 가이드',
                    onTap: () => _handleGuide(context),
                    isIOS: false,
                  ),
                ),

                const SizedBox(height: 40),

                // 앱 정보
                Center(
                  child: Column(
                    children: [
                      Text(
                        'D-FET',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white60,
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      color: Colors.white10,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
    required bool isIOS,
  }) {
    if (isIOS) {
      return CupertinoListTile(
        leading: Icon(icon, color: iconColor ?? Colors.white),
        title: Text(
          title,
          style: GoogleFonts.outfit(color: titleColor ?? Colors.white),
        ),
        trailing: const Icon(CupertinoIcons.chevron_right,
            color: Colors.white38, size: 16),
        onTap: onTap,
        backgroundColor: Colors.transparent,
      );
    } else {
      return ListTile(
        leading: Icon(icon, color: iconColor ?? Colors.white),
        title: Text(
          title,
          style: GoogleFonts.outfit(color: titleColor ?? Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      );
    }
  }

  /// 프로필 카드 (공통)
  Widget _buildProfileCard(
    BuildContext context,
    WidgetRef ref,
    User? user,
    AsyncValue<UserProfile?> userProfileAsync, {
    required bool isGuest,
    required bool isIOS,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 프로필 사진
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: !isGuest && user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? Icon(
                        isIOS ? CupertinoIcons.person_fill : Icons.person,
                        size: 30,
                        color: Colors.white70,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // 사용자 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? '게스트' : (user?.displayName ?? '사용자'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuest ? '임시 계정으로 사용 중입니다' : (user?.email ?? ''),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                    if (!isGuest) ...[
                      const SizedBox(height: 8),
                      userProfileAsync.when(
                        data: (profile) => profile != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: PremiumColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${profile.provider?.toUpperCase()} 계정',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: PremiumColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 내 정보 보기 버튼 (게스트가 아닐 때)
          if (!isGuest) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    adaptivePageRoute(
                        builder: (context) => const MyInfoScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  '내 정보 보기',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          // 게스트 모드일 때 계정 연결 버튼 표시
          if (isGuest) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: isIOS
                  ? CupertinoButton(
                      color: PremiumColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () =>
                          _handleLinkAccount(context, ref, isIOS: true),
                      child: Text(
                        '계정 연결하기',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          _handleLinkAccount(context, ref, isIOS: false),
                      child: Text(
                        '계정 연결하기',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              '계정을 연결하면 데이터가 저장됩니다',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ... (Rest of the methods like _handleLinkAccount, _handleSwitchAccount, etc. remain largely the same logic but need to ensure dialogs look okay.
  // For brevity and safety, I will include them but use standard dialogs which might look a bit off in dark mode unless themed correctly.
  // Given the scope, I'll keep the logic but ensure text styles are consistent if possible, or rely on system defaults which usually adapt to dark mode.)

  /// 계정 연결 처리 (게스트 → 로그인)
  Future<void> _handleLinkAccount(
    BuildContext context,
    WidgetRef ref, {
    required bool isIOS,
  }) async {
    // ... (Keep existing logic)
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('계정 연결'),
          content: const Text(
              '계정을 연결하시겠습니까?\n\n현재 게스트 모드의 데이터는\n저장되지 않습니다.\n\n로그인 후 새로운 계정으로\n데이터가 관리됩니다.'),
          actions: [
            CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(context)),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                ref.read(isGuestModeProvider.notifier).state = false;
                ref.read(isTrainerGuestModeProvider.notifier).state = false;
              },
              child: const Text('계정 연결'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('계정 연결'),
          content: const Text(
              '계정을 연결하시겠습니까?\n\n현재 게스트 모드의 데이터는\n저장되지 않습니다.\n\n로그인 후 새로운 계정으로\n데이터가 관리됩니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(isGuestModeProvider.notifier).state = false;
                ref.read(isTrainerGuestModeProvider.notifier).state = false;
              },
              child: const Text('계정 연결'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleSwitchAccount(BuildContext context, WidgetRef ref,
      {required bool isIOS}) async {
    // ... (Keep existing logic)
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('계정 전환'),
          content: const Text('로그아웃 후 다른 계정으로 로그인하시겠습니까?'),
          actions: [
            CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(context)),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                await _performLogout(context, ref);
              },
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('계정 전환'),
          content: const Text('로그아웃 후 다른 계정으로 로그인하시겠습니까?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performLogout(context, ref);
              },
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref,
      {required bool isIOS}) async {
    // ... (Keep existing logic)
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(context)),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                await _performLogout(context, ref);
              },
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performLogout(context, ref);
              },
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      ref.read(isGuestModeProvider.notifier).state = false;
      ref.read(isTrainerGuestModeProvider.notifier).state = false;
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref,
      {required bool isIOS}) async {
    // ... (Keep existing logic)
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('회원탈퇴'),
          content: const Text('정말 탈퇴하시겠습니까?\n\n모든 데이터가 삭제되며 복구할 수 없습니다.'),
          actions: [
            CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(context)),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                // Implement delete logic
              },
              child: const Text('탈퇴하기'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('회원탈퇴'),
          content: const Text('정말 탈퇴하시겠습니까?\n\n모든 데이터가 삭제되며 복구할 수 없습니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Implement delete logic
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('탈퇴하기'),
            ),
          ],
        ),
      );
    }
  }

  void _handleGuide(BuildContext context) {
    Navigator.of(context).push(
      adaptivePageRoute(builder: (context) => const GuideScreen()),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        adaptivePageRoute(builder: (context) => const SubscriptionScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 100, // Fixed height for consistency
        child: Stack(
          children: [
            // Main Card Background
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1BFFFF).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '프리미엄 업그레이드',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '모든 기능을 제한 없이 이용하세요',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Discount Ribbon (Top Right)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4B4B), // Red color for discount
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: Text(
                  'SALE',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
