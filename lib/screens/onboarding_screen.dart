import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/user_state.dart';
import '../state/app_state.dart';
import '../models/user_profile.dart';
import '../core/utils/app_logger.dart';
import '../state/auth_state.dart';
import '../state/onboarding_state.dart';
import '../theme/tokens.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dfet_logo_mark.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form Data
  String? _careType; // 2026 개편: 'microbiome' | 'fitness' | 'both'
  String? _goal;
  String? _gender;
  int _age = 25;
  double _height = 170.0;
  double _weight = 65.0;
  String? _activityLevel;

  // Animation State
  bool _isAnalyzing = false;

  final List<String> _goals = [
    "체중 감량",
    "근육 증가",
    "체력 증진",
    "체형 교정",
  ];

  final List<String> _activityLevels = [
    "Sedentary (거의 운동 안함)",
    "Lightly Active (주 1-3회)",
    "Moderately Active (주 3-5회)",
    "Very Active (주 6-7회)",
    "Extra Active (매일 격렬한 운동)",
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isAnalyzing = true;
    });

    // Simulate AI Analysis
    await Future.delayed(const Duration(seconds: 3));

    try {
      final user = ref.read(currentUserProvider);

      if (user != null) {
        // 로그인된 사용자: 프로필 업데이트
        final userProfile = await ref.read(userProfileProvider.future);
        if (userProfile != null) {
          final updatedProfile = userProfile.copyWith(
            gender: _gender,
            age: _age,
            height: _height,
            weight: _weight,
            activityLevel: _activityLevel,
            careType: _careType ?? UserCareType.fitness,
            isOnboardingComplete: true,
          );

          // 게스트 케어 유형 상태도 동기화 (탭 분기에 즉시 반영)
          ref.read(guestCareTypeProvider.notifier).state =
              _careType ?? UserCareType.fitness;

          AppLogger.info('Selected Goal: $_goal');

          // Save to Firestore
          await ref
              .read(firestoreServiceProvider)
              .updateUserProfile(updatedProfile);

          // Invalidate provider to trigger refresh in main.dart
          ref.invalidate(userProfileProvider);

          AppLogger.info('Onboarding completed for ${userProfile.email}');
        }
      } else {
        // 비로그인 사용자: 온보딩 완료 플래그 + 케어 유형 저장 후 로그인 화면으로 이동
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool('hasSeenOnboarding', true);
        await prefs.setString(
            'guestCareType', _careType ?? UserCareType.fitness);
        ref.read(hasSeenOnboardingProvider.notifier).state = true;
        ref.read(guestCareTypeProvider.notifier).state =
            _careType ?? UserCareType.fitness;

        AppLogger.info('Onboarding completed for guest/new user');
      }

      // 로그인 화면으로 이동 (main.dart에서 상태 변화 감지하여 자동 전환됨)
    } catch (e) {
      AppLogger.error('Onboarding failed', e);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return _buildAnalyzingPage();
    }

    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      body: Container(
        color: context.wellness.bgRoot,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _responsivePage(_buildWelcomePage()),
                    _responsivePage(_buildCareTypePage()),
                    _responsivePage(_buildGoalPage()),
                    _responsivePage(_buildGenderPage()),
                    _responsivePage(_buildWheelPickerPage(
                      title: "나이",
                      subtitle: "만 나이를 알려주세요.",
                      value: _age,
                      min: 10,
                      max: 100,
                      unit: "세",
                      onChanged: (val) => setState(() => _age = val),
                    )),
                    _responsivePage(_buildWheelPickerPage(
                      title: "키",
                      subtitle: "정확한 분석을 위해 필요합니다.",
                      value: _height.toInt(),
                      min: 100,
                      max: 250,
                      unit: "cm",
                      onChanged: (val) =>
                          setState(() => _height = val.toDouble()),
                    )),
                    _responsivePage(_buildWheelPickerPage(
                      title: "몸무게",
                      subtitle: "체질량 지수(BMI) 계산에 사용됩니다.",
                      value: _weight.toInt(),
                      min: 30,
                      max: 200,
                      unit: "kg",
                      onChanged: (val) =>
                          setState(() => _weight = val.toDouble()),
                    )),
                    _responsivePage(_buildActivityLevelPage()),
                    _responsivePage(_buildPermissionPage(),
                        maxWidth: ResponsiveLayout.maxFormWidth),
                  ],
                ),
              ),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _responsivePage(Widget child,
      {double maxWidth = ResponsiveLayout.maxSetupWidth}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(child: child),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  color: context.wellness.textPrimary, size: 20),
              onPressed: _previousPage,
            )
          else
            const SizedBox(width: 40),

          // Progress Indicator
          Row(
            children: List.generate(9, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: _currentPage == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? context.wellness.primary
                      : context.wellness.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.wellness.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.wellness.primary.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const DfetLogoMark(
              size: 120,
              contrastBackground: false,
            ),
          ),
          const SizedBox(height: 60),
          Text(
            "DFET COACH",
            style: GoogleFonts.outfit(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: context.wellness.textPrimary,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "당신만의 AI 퍼스널 트레이너",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: context.wellness.textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildCareTypePage() {
    final options = [
      {
        'type': UserCareType.fitness,
        'icon': Icons.fitness_center_rounded,
        'title': '운동 · 신체조성',
        'desc': '운동 기록, AI 자세분석, 식단 관리로\n체형과 컨디션을 관리해요.',
      },
      {
        'type': UserCareType.microbiome,
        'icon': Icons.biotech_rounded,
        'title': '장내미생물 케어',
        'desc': '장내미생물 분석 리포트로\n장 건강과 저속노화를 관리해요.',
      },
      {
        'type': UserCareType.both,
        'icon': Icons.all_inclusive_rounded,
        'title': '통합 케어',
        'desc': '운동·식단과 장내미생물을\n모두 함께 관리해요.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "어떤 케어를\n받고 싶으세요?",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "선택에 따라 맞춤 화면을 구성해 드려요. (나중에 변경 가능)",
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: context.wellness.textTertiary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final opt = options[index];
                final isSelected = _careType == opt['type'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _careType = opt['type'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.wellness.primary
                          : context.wellness.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : context.wellness.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : context.wellness.bgSubtle,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            opt['icon'] as IconData,
                            color: isSelected
                                ? Colors.white
                                : context.wellness.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : context.wellness.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                opt['desc'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white70
                                      : context.wellness.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "어떤 목표를\n가지고 계신가요?",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 680 ? 4 : 2;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: crossAxisCount == 4 ? 0.78 : 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    final isSelected = _goal == goal;
                    return GestureDetector(
                      onTap: () => setState(() => _goal = goal),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.wellness.primary
                              : context.wellness.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : context.wellness.border,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.asset(
                                  _getGoalImagePath(goal),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                goal,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : context.wellness.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getGoalImagePath(String goal) {
    switch (goal) {
      case "체중 감량":
        return 'assets/image/goal_weight_loss.png';
      case "근육 증가":
        return 'assets/image/goal_muscle_gain.png';
      case "체력 증진":
        return 'assets/image/goal_stamina.png';
      case "체형 교정":
        return 'assets/image/goal_posture.png';
      default:
        return 'assets/image/goal_weight_loss.png';
    }
  }

  Widget _buildGenderPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "성별을\n선택해주세요",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 620) {
                  return Row(
                    children: [
                      _buildGenderCard("Male", "남성", Icons.male),
                      const SizedBox(width: 20),
                      _buildGenderCard("Female", "여성", Icons.female),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildGenderCard("Male", "남성", Icons.male),
                    const SizedBox(height: 20),
                    _buildGenderCard("Female", "여성", Icons.female),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGenderCard(String value, String label, IconData icon) {
    final isSelected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isSelected ? context.wellness.primary : context.wellness.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.transparent : context.wellness.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 60,
                color: isSelected
                    ? Colors.white
                    : context.wellness.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : context.wellness.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheelPickerPage({
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: context.wellness.textTertiary,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: value - min,
                    ),
                    itemExtent: 60,
                    onSelectedItemChanged: (index) {
                      onChanged(min + index);
                    },
                    selectionOverlay: Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(
                              color: context.wellness.primary, width: 2),
                        ),
                      ),
                    ),
                    children: List.generate(max - min + 1, (index) {
                      final itemValue = min + index;
                      return Center(
                        child: Text(
                          "$itemValue",
                          style: GoogleFonts.outfit(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: context.wellness.textPrimary,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Text(
                  unit,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    color: context.wellness.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "평소 활동량은\n어느 정도인가요?",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: _activityLevels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final level = _activityLevels[index];
                final isSelected = _activityLevel == level;
                return GestureDetector(
                  onTap: () => setState(() => _activityLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.wellness.primary
                          : context.wellness.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : context.wellness.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            level,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : context.wellness.textSecondary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.wellness.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.security_rounded,
              size: 60,
              color: context.wellness.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "마지막 단계입니다!",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "AI 코칭을 위해 카메라 권한과\n알림 권한이 필요합니다.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: context.wellness.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _buildPermissionButton(
            icon: Icons.camera_alt_rounded,
            label: "카메라 권한 허용",
            onTap: () => Permission.camera.request(),
          ),
          const SizedBox(height: 16),
          _buildPermissionButton(
            icon: Icons.notifications_active_rounded,
            label: "알림 권한 허용",
            onTap: () => Permission.notification.request(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: context.wellness.primaryDark),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.wellness.primaryDark,
          side: BorderSide(color: context.wellness.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingPage() {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      body: Container(
        color: context.wellness.bgRoot,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: context.wellness.primary,
                strokeWidth: 4,
              ),
              const SizedBox(height: 40),
              Text(
                "AI가 데이터를 분석중입니다...",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.wellness.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "잠시만 기다려주세요.",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: context.wellness.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    bool isLastPage = _currentPage == 8; // Permission page (케어유형 추가로 +1)
    bool isWelcomePage = _currentPage == 0;
    bool isCareTypePage = _currentPage == 1;

    // 케어 유형 페이지에서는 선택해야 다음으로 진행 가능
    final bool canProceed = !isCareTypePage || _careType != null;

    return ResponsiveConstrainedBox(
      maxWidth: ResponsiveLayout.maxFormWidth,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: !canProceed
                ? null
                : () {
                    if (isLastPage) {
                      _completeOnboarding();
                    } else {
                      _nextPage();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.wellness.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  context.wellness.primary.withOpacity(0.3),
              disabledForegroundColor: Colors.white54,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isWelcomePage ? "시작하기" : (isLastPage ? "완료" : "다음"),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
