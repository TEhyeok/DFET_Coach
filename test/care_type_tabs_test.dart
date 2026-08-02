import 'package:flutter_test/flutter_test.dart';
import 'package:dfet_coach/models/user_profile.dart';
import 'package:dfet_coach/widgets/shells/ios_shell.dart';
import 'package:dfet_coach/widgets/shells/ios_destination.dart';

void main() {
  group('하단 탭 구성 (2026 개편: 4탭 고정)', () {
    test('careType 무관하게 항상 홈·기록·리포트·내정보 4탭', () {
      for (final ct in [
        UserCareType.fitness,
        UserCareType.microbiome,
        UserCareType.both,
        'unknown',
      ]) {
        final d = destinationsForCareType(ct);
        expect(d.length, 4, reason: 'careType=$ct');
        expect(d, [
          IOSDestination.home,
          IOSDestination.record,
          IOSDestination.report,
          IOSDestination.profile,
        ]);
      }
    });

    test('커뮤니티/코칭/장건강은 탭에서 제외 (리포트/내정보로 통합)', () {
      final d = destinationsForCareType(UserCareType.both);
      expect(d.contains(IOSDestination.community), false);
      expect(d.contains(IOSDestination.coaching), false);
      expect(d.contains(IOSDestination.microbiome), false);
    });

    test('리포트 탭이 항상 포함된다', () {
      expect(destinationsForCareType(UserCareType.fitness)
          .contains(IOSDestination.report), true);
      expect(destinationsForCareType(UserCareType.microbiome)
          .contains(IOSDestination.report), true);
    });
  });

  group('UserProfile careType 직렬화', () {
    test('careType 기본값은 fitness', () {
      final p = UserProfile(
        uid: 'u1',
        createdAt: DateTime(2026),
        lastLoginAt: DateTime(2026),
      );
      expect(p.careType, UserCareType.fitness);
    });

    test('toMap/fromMap 라운드트립', () {
      final p = UserProfile(
        uid: 'u1',
        createdAt: DateTime(2026),
        lastLoginAt: DateTime(2026),
        careType: UserCareType.microbiome,
      );
      final restored = UserProfile.fromMap(p.toMap(), 'u1');
      expect(restored.careType, UserCareType.microbiome);
    });

    test('careType 누락 시 fitness로 폴백', () {
      final restored = UserProfile.fromMap({'email': 'a@b.com'}, 'u1');
      expect(restored.careType, UserCareType.fitness);
    });
  });
}
