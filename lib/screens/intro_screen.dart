import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/onboarding_state.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dfet_logo_mark.dart';
import 'login_screen.dart';

class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

  static const Color _primaryColor = Color(0xFFE94560);
  static const Color _bgGradientStart = Color(0xFF1A1A2E);
  static const Color _bgGradientEnd = Color(0xFF16213E);

  Future<void> _onStart(BuildContext context, WidgetRef ref) async {
    // 온보딩 완료 처리 (인트로 봄)
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('hasSeenOnboarding', true);
    ref.read(hasSeenOnboardingProvider.notifier).state = true;

    // 로그인 화면은 main.dart의 상태 변화에 의해 자동으로 전환되거나,
    // 명시적으로 이동할 수도 있음. 여기서는 상태 업데이트만으로 충분할 수 있으나
    // 부드러운 전환을 위해 직접 이동할 수도 있음.
    // 하지만 main.dart의 AnimatedSwitcher가 처리하도록 두는 것이 좋음.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgGradientStart, _bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: ResponsiveConstrainedBox(
            maxWidth: ResponsiveLayout.maxFormWidth,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.2),
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
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "당신만의 AI 퍼스널 트레이너",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _onStart(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "시작하기",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
