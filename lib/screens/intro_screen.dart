import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/onboarding_state.dart';
import '../theme/tokens.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dfet_logo_mark.dart';
import 'login_screen.dart';

class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

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
      backgroundColor: context.wellness.bgRoot,
      body: Container(
        color: context.wellness.bgRoot,
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
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _onStart(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.wellness.primary,
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
