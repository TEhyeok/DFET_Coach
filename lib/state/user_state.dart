import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../core/utils/app_logger.dart';
import 'app_state.dart'; // For firestoreServiceProvider

/// 사용자 프로필 Provider (Firestore에서 로드)
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final firestoreService = ref.watch(firestoreServiceProvider);
    final doc = await firestoreService.getUserProfile(user.uid);

    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!, user.uid);
    } else {
      // 첫 로그인 - 프로필 생성
      final hasSelectedCareType = ref.read(hasSeenOnboardingProvider);
      final selectedCareType = ref.read(guestCareTypeProvider);
      final now = DateTime.now();
      final newProfile = UserProfile(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoURL: user.photoURL,
        provider: user.providerData.isNotEmpty
            ? user.providerData.first.providerId.replaceAll('.com', '')
            : 'unknown',
        createdAt: now,
        lastLoginAt: now,
        careType: selectedCareType,
        careTypeVersion: hasSelectedCareType ? 1 : 0,
        careTypeConfirmedAt: hasSelectedCareType ? now : null,
      );

      final storedProfile =
          await firestoreService.createUserProfileIfAbsent(newProfile);
      AppLogger.info('[userProfileProvider] 새 사용자 프로필 생성: ${user.email}');
      return storedProfile;
    }
  } catch (e, stackTrace) {
    AppLogger.error('[userProfileProvider] 사용자 프로필 로드 실패', e, stackTrace);
    return null;
  }
});
