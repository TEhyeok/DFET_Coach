import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'admin/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: AdminApp(),
    ),
  );
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminRouter = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: 'D-FET 관리자',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFEC4445),
          secondary: Color(0xFF198754),
          error: Color(0xFFDC3545),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111827),
        ),
      ),
      routerConfig: adminRouter,
    );
  }
}
