import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../core/utils/app_logger.dart';

/// Firebase Authentication 서비스
/// Google 및 Apple 소셜 로그인 지원
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 현재 로그인한 사용자
  User? get currentUser => _auth.currentUser;

  /// 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Google 로그인
  ///
  /// Returns: [UserCredential] 로그인 성공 시
  /// Throws: [FirebaseAuthException] 로그인 실패 시
  Future<UserCredential?> signInWithGoogle() async {
    try {
      AppLogger.info('Google 로그인 시작');

      // Google 로그인 프로세스 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인 취소
        AppLogger.info('Google 로그인 취소됨');
        return null;
      }

      // 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase 자격증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase로 로그인
      final userCredential = await _auth.signInWithCredential(credential);

      AppLogger.info('Google 로그인 성공: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Google 로그인 실패', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Google 로그인 중 예상치 못한 오류', e, stackTrace);
      rethrow;
    }
  }

  /// Apple 로그인
  ///
  /// Returns: [UserCredential] 로그인 성공 시
  /// Throws: [FirebaseAuthException] 로그인 실패 시
  Future<UserCredential?> signInWithApple() async {
    try {
      AppLogger.info('Apple 로그인 시작');

      // nonce 생성 (보안을 위해)
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Apple 로그인 요청
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Firebase용 OAuthCredential 생성
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Firebase로 로그인
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple은 첫 로그인 시에만 이름을 제공
      // displayName이 없으면 Apple에서 받은 이름으로 업데이트
      if (userCredential.user != null &&
          userCredential.user!.displayName == null &&
          appleCredential.givenName != null) {
        final displayName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }

      AppLogger.info('Apple 로그인 성공: ${userCredential.user?.email}');
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e, stackTrace) {
      if (e.code == AuthorizationErrorCode.canceled) {
        AppLogger.info('Apple 로그인 취소됨');
        return null;
      }
      AppLogger.error('Apple 로그인 실패', e, stackTrace);
      rethrow;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('Apple 로그인 Firebase 인증 실패', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Apple 로그인 중 예상치 못한 오류', e, stackTrace);
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      AppLogger.info('로그아웃 시작');

      // Google 로그인 상태 확인 후 로그아웃
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Firebase 로그아웃
      await _auth.signOut();

      AppLogger.info('로그아웃 완료');
    } catch (e, stackTrace) {
      AppLogger.error('로그아웃 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 회원탈퇴
  ///
  /// 주의: 사용자 데이터는 별도로 삭제해야 함 (Firestore 등)
  Future<void> deleteAccount() async {
    try {
      AppLogger.info('회원탈퇴 시작');

      final user = currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      // Firebase 계정 삭제
      await user.delete();

      // Google 로그인 정보도 제거
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      AppLogger.info('회원탈퇴 완료');
    } on FirebaseAuthException catch (e, stackTrace) {
      if (e.code == 'requires-recent-login') {
        AppLogger.error('재인증이 필요합니다', e, stackTrace);
        throw Exception('보안을 위해 다시 로그인한 후 회원탈퇴를 진행해주세요');
      }
      AppLogger.error('회원탈퇴 실패', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('회원탈퇴 중 예상치 못한 오류', e, stackTrace);
      rethrow;
    }
  }

  /// 재인증 (회원탈퇴 전 필요)
  Future<UserCredential?> reauthenticate() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      // 사용자의 로그인 제공자 확인
      final providerData = user.providerData;
      if (providerData.isEmpty) {
        throw Exception('로그인 제공자 정보를 찾을 수 없습니다');
      }

      final providerId = providerData.first.providerId;

      if (providerId == 'google.com') {
        return await signInWithGoogle();
      } else if (providerId == 'apple.com') {
        return await signInWithApple();
      } else if (providerId == 'password') {
        // 비밀번호 재인증은 UI에서 비밀번호를 받아야 하므로 여기서는 처리 불가
        // 별도 메서드로 분리하거나 UI에서 reauthenticateWithCredential 사용 필요
        throw Exception('비밀번호 재인증이 필요합니다');
      } else {
        throw Exception('지원하지 않는 로그인 제공자입니다: $providerId');
      }
    } catch (e, stackTrace) {
      AppLogger.error('재인증 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 이메일/비밀번호 로그인
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      AppLogger.info('이메일 로그인 시도: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('이메일 로그인 성공: $email');
      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('이메일 로그인 실패', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('이메일 로그인 중 예상치 못한 오류', e, stackTrace);
      rethrow;
    }
  }

  /// 이메일/비밀번호 회원가입
  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      AppLogger.info('이메일 회원가입 시도: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('이메일 회원가입 성공: $email');
      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      AppLogger.error('이메일 회원가입 실패', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('이메일 회원가입 중 예상치 못한 오류', e, stackTrace);
      rethrow;
    }
  }

  // === Private Helper Methods ===

  /// Nonce 생성 (Apple 로그인용)
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA256 해시 생성
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
