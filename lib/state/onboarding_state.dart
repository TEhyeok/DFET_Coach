import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences Provider (Initialized in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// 온보딩 완료 여부 Provider
final hasSeenOnboardingProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('hasSeenOnboarding') ?? false;
});
