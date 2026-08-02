import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/admin_theme.dart';
import 'router/app_router.dart';
import 'state/app_state.dart';
import 'state/theme_provider.dart';
import 'core/utils/app_logger.dart';

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
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
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
    } else {
      final mobileRouter = ref.watch(mobileRouterProvider);
      return MaterialApp.router(
        title: 'D-FET',
        theme: appThemeLight(),
        darkTheme: appThemeDark(),
        themeMode: themeMode,
        routerConfig: mobileRouter,
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
