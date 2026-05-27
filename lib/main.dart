import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/ios_theme.dart';
import 'theme/admin_theme.dart';
import 'screens/login_screen.dart';
import 'screens/intro_screen.dart'; // Import IntroScreen
import 'screens/profile_setup_screen.dart'; // Import ProfileSetupScreen
import 'state/app_state.dart';
import 'state/theme_provider.dart';
import 'core/utils/app_logger.dart';
import 'widgets/shells/ios_shell.dart';
import 'widgets/shells/material_shell.dart';
import 'widgets/shells/trainer_shell.dart';

import 'admin/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase 초기화 성공');

    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      AppLogger.info('App Check 초기화 성공');
    }
  } catch (e, stackTrace) {
    AppLogger.error('Firebase 초기화 실패', e, stackTrace);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로그인 상태 확인 (Firebase User + 게스트 모드)
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final authState = ref.watch(authStateProvider);
    final userProfileAsync =
        ref.watch(userProfileProvider); // Watch user profile
    final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);
    final isTrainerGuest = ref.watch(isTrainerGuestModeProvider);

    // 웹에서는 Material, iOS에서는 Cupertino, Android에서는 Material
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final themeMode = ref.watch(themeModeProvider);

    if (kIsWeb) {
      // 웹(관리자)은 새로운 Admin Router 사용
      final adminRouter = ref.watch(adminRouterProvider);

      return MaterialApp.router(
        title: 'D-FET Admin',
        theme: AdminTheme.lightTheme,
        darkTheme: AdminTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: adminRouter,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
      );
    } else if (isIOS) {
      return CupertinoApp(
        title: 'D-FET',
        theme: themeMode == ThemeMode.light ? iosThemeLight() : iosThemeDark(),
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: authState.when(
            data: (user) {
              if (!isLoggedIn) {
                // 로그인하지 않은 경우
                if (!hasSeenOnboarding) {
                  // 앱을 처음 켠 경우: 인트로 화면
                  return const IntroScreen(key: ValueKey('intro'));
                } else {
                  // 인트로는 봤지만 로그인은 안 한 경우: 로그인 화면
                  return const LoginScreen(key: ValueKey('login'));
                }
              }

              if (isTrainerGuest) {
                return const TrainerShell(
                  key: ValueKey('trainer_guest_shell'),
                  autoOpenNativeHome: true,
                );
              }

              // 로그인한 경우: 프로필 확인
              return userProfileAsync.when(
                data: (profile) {
                  if (profile?.isTrainer == true || profile?.isAdmin == true) {
                    return const TrainerShell(
                      key: ValueKey('trainer_shell'),
                      autoOpenNativeHome: true,
                    );
                  }
                  // 프로필이 없거나 온보딩이 완료되지 않은 경우: 프로필 설정 화면
                  if (profile != null && !profile.isOnboardingComplete) {
                    return const ProfileSetupScreen(
                        key: ValueKey('profile_setup'));
                  }
                  // 모든 설정 완료: 메인 쉘
                  return const IOSShell(key: ValueKey('shell'));
                },
                loading: () => const CupertinoPageScaffold(
                  key: ValueKey('loading'),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                error: (_, __) => const IOSShell(
                    key: ValueKey('shell_error')), // Fallback to Shell on error
              );
            },
            loading: () => const CupertinoPageScaffold(
              key: ValueKey('loading_auth'),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (_, __) => const LoginScreen(key: ValueKey('login_error')),
          ),
        ),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        builder: (context, child) {
          return Material(
            type: MaterialType.transparency,
            child: ScaffoldMessenger(
              child: child!,
            ),
          );
        },
      );
    } else {
      return MaterialApp(
        title: 'D-FET',
        theme: appThemeLight(),
        darkTheme: appThemeDark(),
        themeMode: themeMode,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: authState.when(
            data: (user) {
              if (!isLoggedIn) {
                // 로그인하지 않은 경우
                if (!hasSeenOnboarding) {
                  // 앱을 처음 켠 경우: 인트로 화면
                  return const IntroScreen(key: ValueKey('intro'));
                } else {
                  // 인트로는 봤지만 로그인은 안 한 경우: 로그인 화면
                  return const LoginScreen(key: ValueKey('login'));
                }
              }

              if (isTrainerGuest) {
                return const TrainerShell(
                  key: ValueKey('trainer_guest_shell'),
                  autoOpenNativeHome: true,
                );
              }

              return userProfileAsync.when(
                data: (profile) {
                  if (profile?.isTrainer == true || profile?.isAdmin == true) {
                    return const TrainerShell(
                      key: ValueKey('trainer_shell'),
                      autoOpenNativeHome: true,
                    );
                  }
                  if (profile != null && !profile.isOnboardingComplete) {
                    return const ProfileSetupScreen(
                        key: ValueKey('profile_setup'));
                  }
                  return const MaterialShell(key: ValueKey('shell'));
                },
                loading: () => const Scaffold(
                  key: ValueKey('loading'),
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const MaterialShell(key: ValueKey('shell_error')),
              );
            },
            loading: () => const Scaffold(
              key: ValueKey('loading_auth'),
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const LoginScreen(key: ValueKey('login_error')),
          ),
        ),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
      );
    }
  }
}
