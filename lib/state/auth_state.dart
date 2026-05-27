import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// === Authentication Providers ===

/// AuthService Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// 현재 Firebase User Stream
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// 현재 로그인한 사용자 정보 (nullable)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// 로그인 여부
final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  final isGuest = ref.watch(isGuestModeProvider);
  final isTrainerGuest = ref.watch(isTrainerGuestModeProvider);
  return user != null || isGuest || isTrainerGuest;
});

/// 게스트 모드 상태
final isGuestModeProvider = StateProvider<bool>((ref) => false);

/// 트레이너 게스트 모드 상태
final isTrainerGuestModeProvider = StateProvider<bool>((ref) => false);

/// 현재 사용자 UID (로그인 사용자 또는 게스트)
final currentUidProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  final isGuest = ref.watch(isGuestModeProvider);
  final isTrainerGuest = ref.watch(isTrainerGuestModeProvider);

  if (user != null) return user.uid;
  if (isTrainerGuest) return 'trainer_guest';
  if (isGuest) return 'guest';
  return null;
});
