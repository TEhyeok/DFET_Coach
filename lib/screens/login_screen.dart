import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_state.dart';
import '../core/utils/app_logger.dart';
import '../models/user_profile.dart';
import '../models/admin_profile.dart';
import '../services/admin_auth_service.dart';
import '../theme/tokens.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dfet_logo_mark.dart';
import '../widgets/ios_adaptive_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  // Web Auth State
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // For Sign Up
  bool _isSignUp = false; // Toggle between Login and Sign Up

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// 이메일 로그인 처리 (Web - Admin Only)
  Future<void> _handleEmailSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('이메일과 비밀번호를 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (userCredential.user != null && mounted) {
        final user = userCredential.user!;
        final adminAuthService = AdminAuthService();

        // 일반 관리자: admins 컬렉션에서 승인 여부 확인
        final adminDoc = await adminAuthService.getAdminProfile(user.uid);

        if (!adminDoc.exists) {
          // admins 컬렉션에 없음 -> 관리자가 아님
          await authService.signOut();
          if (mounted) {
            _showErrorDialog('관리자 계정이 아닙니다.');
          }
          return;
        }

        final adminProfile = AdminProfile.fromMap(
          adminDoc.data() as Map<String, dynamic>,
          user.uid,
        );

        // 승인 상태 확인
        if (adminProfile.isPending) {
          await authService.signOut();
          if (mounted) {
            _showErrorDialog('관리자 승인 대기 중입니다.\n승인이 완료되면 접속할 수 있습니다.');
          }
          return;
        } else if (adminProfile.isRejected) {
          await authService.signOut();
          if (mounted) {
            _showErrorDialog('관리자 승인이 거부되었습니다.');
          }
          return;
        } else if (adminProfile.isApproved) {
          // 승인됨 -> 로그인 성공
          await adminAuthService.updateLastLogin(user.uid);
          AppLogger.info('[LoginScreen] 관리자 로그인 성공: ${adminProfile.email}');
          // authStateProvider가 자동으로 감지하여 화면 전환
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = '로그인 실패';
      if (e.code == 'user-not-found') {
        message = '가입되지 않은 이메일입니다';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 올바르지 않습니다';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다';
      } else if (e.code == 'invalid-credential') {
        message = '이메일 또는 비밀번호가 올바르지 않습니다';
      }
      _showErrorDialog(message);
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('[LoginScreen] 이메일 로그인 오류', e, StackTrace.current);
      _showErrorDialog('로그인 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 이메일 회원가입 처리 (Web - Admin Only)
  Future<void> _handleEmailSignUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      _showErrorDialog('모든 정보를 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (userCredential.user != null && mounted) {
        final user = userCredential.user!;
        final adminAuthService = AdminAuthService();

        // admins 컬렉션에 승인 대기 상태로 저장
        await adminAuthService.createAdminRequest(
          uid: user.uid,
          email: user.email ?? _emailController.text.trim(),
          displayName: _nameController.text.trim(),
        );

        AppLogger.info('관리자 계정 생성 완료: ${user.email}, 승인 대기');

        // 가입 후 즉시 로그아웃 (중요: 다이얼로그 전에 로그아웃)
        await authService.signOut();

        // 로그아웃 후 상태가 반영될 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          setState(() => _isSignUp = false); // 로그인 화면으로 전환

          await showDialog(
            context: context,
            barrierDismissible: false, // 바깥 클릭으로 닫기 방지
            builder: (context) => AlertDialog(
              title: const Text('승인 신청 완료'),
              content: const Text('관리자 승인 신청이 완료되었습니다.\n승인이 완료되면 이메일로 안내드립니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = '회원가입 실패';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다';
      } else if (e.code == 'weak-password') {
        message = '비밀번호는 6자리 이상이어야 합니다';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다';
      }
      _showErrorDialog(message);
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('[LoginScreen] 회원가입 오류', e, StackTrace.current);
      _showErrorDialog('회원가입 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Google 로그인 처리
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();

      if (userCredential != null && mounted) {
        AppLogger.info('[LoginScreen] Google 로그인 성공');
        // 로그인 성공 시 authStateProvider가 자동으로 화면 전환 처리
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Google 로그인 실패';
      if (e.code == 'account-exists-with-different-credential') {
        message = '이미 다른 방법으로 가입된 이메일입니다';
      } else if (e.code == 'network-request-failed') {
        message = '네트워크 연결을 확인해주세요';
      }

      _showErrorDialog(message);
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('[LoginScreen] Google 로그인 중 오류', e, StackTrace.current);
      _showErrorDialog('로그인 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 게스트 모드로 계속
  void _handleGuestMode() {
    AppLogger.info('[LoginScreen] 게스트 모드로 진입');
    ref.read(isTrainerGuestModeProvider.notifier).state = false;
    ref.read(isGuestModeProvider.notifier).state = true;
    // isLoggedInProvider가 true가 되어 자동으로 메인 화면으로 전환
  }

  void _handleTrainerGuestMode() {
    AppLogger.info('[LoginScreen] 트레이너 게스트 모드로 진입');
    ref.read(isGuestModeProvider.notifier).state = false;
    ref.read(isTrainerGuestModeProvider.notifier).state = true;
  }

  /// Apple 로그인 처리
  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithApple();

      if (userCredential != null && mounted) {
        AppLogger.info('[LoginScreen] Apple 로그인 성공');
        // 로그인 성공 시 authStateProvider가 자동으로 화면 전환 처리
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Apple 로그인 실패';
      if (e.code == 'account-exists-with-different-credential') {
        message = '이미 다른 방법으로 가입된 이메일입니다';
      } else if (e.code == 'network-request-failed') {
        message = '네트워크 연결을 확인해주세요';
      }

      _showErrorDialog(message);
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('[LoginScreen] Apple 로그인 중 오류', e, StackTrace.current);
      _showErrorDialog('로그인 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMemberAuthSheet({bool signUp = true}) {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();

    showAdaptiveEntrySheet<void>(
      context: context,
      builder: (sheetContext) {
        var isSubmitting = false;
        var isSignUp = signUp;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSignUp ? '회원등록' : '이메일 로그인',
                          style: GoogleFonts.outfit(
                            color: context.wellness.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(sheetContext),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: context.wellness.textTertiary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSignUp
                        ? '기록을 저장하고 코칭 리포트를 이어서 관리합니다'
                        : '등록한 이메일 계정으로 계속합니다',
                    style: GoogleFonts.outfit(
                      color: context.wellness.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (isSignUp) ...[
                    _buildTrainerTextField(
                      controller: _nameController,
                      label: '이름',
                      placeholder: '홍길동',
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildTrainerTextField(
                    controller: _emailController,
                    label: '이메일',
                    placeholder: 'member@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildTrainerTextField(
                    controller: _passwordController,
                    label: '비밀번호',
                    placeholder: '6자리 이상',
                    obscureText: true,
                  ),
                  const SizedBox(height: 22),
                  CupertinoButton(
                    color: context.wellness.primary,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setSheetState(() => isSubmitting = true);
                            final didComplete = await _handleMemberEmailAuth(
                                sheetContext,
                                signUp: isSignUp);
                            if (mounted && !didComplete) {
                              setSheetState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(
                            isSignUp ? '회원등록 완료' : '로그인',
                            style: GoogleFonts.outfit(
                              color: context.wellness.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setSheetState(() {
                              isSignUp = !isSignUp;
                              _passwordController.clear();
                            });
                          },
                    child: Text(
                      isSignUp ? '이미 계정이 있어요' : '새 회원으로 등록하기',
                      style: GoogleFonts.outfit(
                        color: context.wellness.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _handleMemberEmailAuth(
    BuildContext sheetContext, {
    required bool signUp,
  }) async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty || (signUp && name.isEmpty)) {
      _showErrorDialog('필수 정보를 모두 입력해주세요');
      return false;
    }
    if (password.length < 6) {
      _showErrorDialog('비밀번호는 6자리 이상이어야 합니다');
      return false;
    }

    try {
      final authService = ref.read(authServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);
      final selectedCareType = ref.read(guestCareTypeProvider);

      final userCredential = signUp
          ? await authService.signUpWithEmailAndPassword(email, password)
          : await authService.signInWithEmailAndPassword(email, password);
      final user = userCredential.user;

      if (user == null) {
        _showErrorDialog('계정 정보를 확인할 수 없습니다');
        return false;
      }

      final now = DateTime.now();
      if (signUp && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      final profileDoc = await firestoreService.getUserProfile(user.uid);
      if (profileDoc.exists) {
        final profile = UserProfile.fromMap(profileDoc.data()!, user.uid);
        await firestoreService.updateUserProfile(
          profile.copyWith(
            displayName: signUp && name.isNotEmpty ? name : profile.displayName,
            lastLoginAt: now,
            careType: signUp && profile.careTypeVersion == 0
                ? selectedCareType
                : profile.careType,
            careTypeVersion: signUp && profile.careTypeVersion == 0
                ? 1
                : profile.careTypeVersion,
            careTypeConfirmedAt: signUp && profile.careTypeVersion == 0
                ? now
                : profile.careTypeConfirmedAt,
          ),
        );
      } else {
        await firestoreService.createUserProfileIfAbsent(
          UserProfile(
            uid: user.uid,
            email: user.email ?? email,
            displayName: signUp ? name : user.displayName,
            photoURL: user.photoURL,
            provider: 'password',
            createdAt: now,
            lastLoginAt: now,
            careType: selectedCareType,
            careTypeVersion: 1,
            careTypeConfirmedAt: now,
          ),
        );
      }

      ref.read(isGuestModeProvider.notifier).state = false;
      ref.read(isTrainerGuestModeProvider.notifier).state = false;
      ref.invalidate(userProfileProvider);

      if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }

      AppLogger.info(
        signUp
            ? '[LoginScreen] 일반 회원등록 성공: $email'
            : '[LoginScreen] 일반 회원 로그인 성공: $email',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      String message = signUp ? '회원등록 실패' : '로그인 실패';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다';
      } else if (e.code == 'weak-password') {
        message = '비밀번호는 6자리 이상이어야 합니다';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다';
      } else if (e.code == 'user-not-found') {
        message = '가입되지 않은 이메일입니다';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = '이메일 또는 비밀번호가 올바르지 않습니다';
      } else if (e.code == 'network-request-failed') {
        message = '네트워크 연결을 확인해주세요';
      }
      _showErrorDialog(message);
    } catch (e) {
      if (!mounted) return false;
      AppLogger.error('[LoginScreen] 일반 회원 인증 오류', e, StackTrace.current);
      _showErrorDialog('회원 처리 중 오류가 발생했습니다');
    }

    return false;
  }

  void _showTrainerLoginSheet() {
    _emailController.clear();
    _passwordController.clear();

    showAdaptiveEntrySheet<void>(
      context: context,
      builder: (sheetContext) {
        var isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '트레이너 ID 로그인',
                          style: GoogleFonts.outfit(
                            color: context.wellness.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(sheetContext),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: context.wellness.textTertiary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '등록된 트레이너 계정으로 SOAP 노트와 회원 관리를 시작합니다',
                    style: GoogleFonts.outfit(
                      color: context.wellness.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildTrainerTextField(
                    controller: _emailController,
                    label: '트레이너 ID',
                    placeholder: 'trainer@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildTrainerTextField(
                    controller: _passwordController,
                    label: '비밀번호',
                    placeholder: '비밀번호',
                    obscureText: true,
                  ),
                  const SizedBox(height: 22),
                  CupertinoButton(
                    color: context.wellness.primary,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setSheetState(() => isSubmitting = true);
                            final didSignIn =
                                await _handleTrainerSignIn(sheetContext);
                            if (mounted && !didSignIn) {
                              setSheetState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(
                            '트레이너로 로그인',
                            style: GoogleFonts.outfit(
                              color: context.wellness.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrainerTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: context.wellness.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          style: TextStyle(color: context.wellness.textPrimary, fontSize: 15),
          placeholder: placeholder,
          placeholderStyle: TextStyle(color: context.wellness.textTertiary),
          decoration: BoxDecoration(
            color: context.wellness.bgSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.wellness.borderSubtle),
          ),
        ),
      ],
    );
  }

  Future<bool> _handleTrainerSignIn(BuildContext sheetContext) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('트레이너 ID와 비밀번호를 입력해주세요');
      return false;
    }

    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithEmailAndPassword(
        email,
        password,
      );
      final user = userCredential.user;

      if (user == null) {
        _showErrorDialog('로그인 정보를 확인할 수 없습니다');
        return false;
      }

      final firestoreService = ref.read(firestoreServiceProvider);
      final profileDoc = await firestoreService.getUserProfile(user.uid);

      if (!profileDoc.exists) {
        await authService.signOut();
        if (mounted) {
          _showErrorDialog('등록된 트레이너 계정이 아닙니다.');
        }
        return false;
      }

      final profile = UserProfile.fromMap(profileDoc.data()!, user.uid);
      if (!profile.isTrainer && !profile.isAdmin) {
        await authService.signOut();
        if (mounted) {
          _showErrorDialog('트레이너 권한이 없는 계정입니다.');
        }
        return false;
      }

      ref.invalidate(userProfileProvider);
      if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }
      AppLogger.info('[LoginScreen] 트레이너 로그인 성공: ${user.email}');
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      String message = '트레이너 로그인 실패';
      if (e.code == 'user-not-found') {
        message = '가입되지 않은 트레이너 ID입니다';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 올바르지 않습니다';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다';
      } else if (e.code == 'invalid-credential') {
        message = '트레이너 ID 또는 비밀번호가 올바르지 않습니다';
      }
      _showErrorDialog(message);
    } catch (e) {
      if (!mounted) return false;
      AppLogger.error('[LoginScreen] 트레이너 로그인 오류', e, StackTrace.current);
      _showErrorDialog('트레이너 로그인 중 오류가 발생했습니다');
    }
    return false;
  }

  /// 에러 다이얼로그 표시
  void _showErrorDialog(String message) {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('알림'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('알림'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      return _buildIOSLayout();
    } else if (kIsWeb) {
      return _buildWebLayout();
    } else {
      return _buildMaterialLayout();
    }
  }

  /// Web Layout (Email/Password)
  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot, // Light mint background
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: context.wellness.bgCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: WellnessShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              const DfetLogoMark(
                size: 80,
                contrastBackground: false,
              ),
              const SizedBox(height: 24),
              Text(
                'D-FET Admin',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.wellness.textPrimary,
                ),
              ),
              const SizedBox(height: 40),

              // Form
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: context.wellness.textPrimary),
                  decoration: InputDecoration(
                    labelText: '이름',
                    labelStyle:
                        TextStyle(color: context.wellness.textSecondary),
                    filled: true,
                    fillColor: context.wellness.bgSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                style: TextStyle(color: context.wellness.textPrimary),
                decoration: InputDecoration(
                  labelText: '이메일',
                  labelStyle: TextStyle(color: context.wellness.textSecondary),
                  filled: true,
                  fillColor: context.wellness.bgSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: context.wellness.textPrimary),
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  labelStyle: TextStyle(color: context.wellness.textSecondary),
                  filled: true,
                  fillColor: context.wellness.bgSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_isSignUp ? _handleEmailSignUp : _handleEmailSignIn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.wellness.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isSignUp ? '회원가입' : '로그인',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.wellness.onPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Toggle Button
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _emailController.clear();
                    _passwordController.clear();
                    _nameController.clear();
                  });
                },
                child: Text(
                  _isSignUp ? '이미 계정이 있으신가요? 로그인' : '계정이 없으신가요? 회원가입',
                  style: GoogleFonts.outfit(
                    color: context.wellness.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Debug Button (Temporary)
              TextButton(
                onPressed: _handleGuestMode,
                child: Text(
                  '관리자 프리패스 (Debug)',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              Divider(color: context.wellness.border),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// iOS Cupertino 스타일 레이아웃
  Widget _buildIOSLayout() {
    return CupertinoPageScaffold(
      backgroundColor: context.wellness.bgRoot, // Light mint background
      child: SafeArea(
        child: Center(
          child: ResponsiveConstrainedBox(
            maxWidth: ResponsiveLayout.maxFormWidth,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 영역
                  const DfetLogoMark(
                    size: 120,
                    contrastBackground: false,
                  ),
                  const SizedBox(height: 24),

                  // 앱 이름
                  Text(
                    'D-FET',
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: context.wellness.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '당신의 건강한 라이프스타일 파트너',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: context.wellness.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // Google 로그인 버튼
                  _buildGoogleButton(isIOS: true),
                  const SizedBox(height: 16),

                  // Apple 로그인 버튼 (iOS만)
                  _buildAppleButton(isIOS: true),
                  const SizedBox(height: 16),

                  _buildMemberEmailButton(isIOS: true),
                  const SizedBox(height: 16),

                  _buildTrainerLoginButton(isIOS: true),
                  const SizedBox(height: 10),
                  _buildTrainerGuestButton(isIOS: true),

                  const SizedBox(height: 24),

                  // 구분선
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.wellness.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '또는',
                          style: GoogleFonts.outfit(
                            color: context.wellness.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.wellness.border)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 게스트 모드 버튼
                  _buildGuestButton(isIOS: true),

                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    CupertinoActivityIndicator(color: context.wellness.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Android Material 스타일 레이아웃
  Widget _buildMaterialLayout() {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot, // Light mint background
      body: SafeArea(
        child: Center(
          child: ResponsiveConstrainedBox(
            maxWidth: ResponsiveLayout.maxFormWidth,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 영역
                  const DfetLogoMark(
                    size: 120,
                    contrastBackground: false,
                  ),
                  const SizedBox(height: 24),

                  // 앱 이름
                  Text(
                    'D-FET',
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: context.wellness.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '당신의 건강한 라이프스타일 파트너',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: context.wellness.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // Google 로그인 버튼
                  _buildGoogleButton(isIOS: false),
                  const SizedBox(height: 16),

                  // Apple 로그인 버튼 (선택적)
                  if (!kIsWeb && Platform.isIOS)
                    _buildAppleButton(isIOS: false),
                  const SizedBox(height: 16),

                  _buildMemberEmailButton(isIOS: false),
                  const SizedBox(height: 16),

                  _buildTrainerLoginButton(isIOS: false),
                  const SizedBox(height: 10),
                  _buildTrainerGuestButton(isIOS: false),

                  const SizedBox(height: 24),

                  // 구분선
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.wellness.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '또는',
                          style: GoogleFonts.outfit(
                            color: context.wellness.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.wellness.border)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 게스트 모드 버튼
                  _buildGuestButton(isIOS: false),

                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    CircularProgressIndicator(color: context.wellness.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Google 로그인 버튼
  Widget _buildGoogleButton({required bool isIOS}) {
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(vertical: 16),
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.google.com/favicon.ico',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(
                  CupertinoIcons.circle_fill,
                  size: 20,
                  color: CupertinoColors.systemRed,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Google로 계속하기',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(color: context.wellness.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.google.com/favicon.ico',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.circle,
                  size: 20,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Google로 계속하기',
                style: GoogleFonts.outfit(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Apple 로그인 버튼
  Widget _buildAppleButton({required bool isIOS}) {
    // Black button with White border for visibility on Black background
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: WellnessShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleAppleSignIn,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.apple,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Apple로 계속하기',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 게스트 모드 버튼
  Widget _buildGuestButton({required bool isIOS}) {
    if (isIOS) {
      return CupertinoButton(
        onPressed: _handleGuestMode,
        child: Text(
          '게스트로 계속하기',
          style: GoogleFonts.outfit(
            color: context.wellness.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    } else {
      return TextButton(
        onPressed: _handleGuestMode,
        child: Text(
          '게스트로 계속하기',
          style: GoogleFonts.outfit(
            color: context.wellness.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }
  }

  Widget _buildMemberEmailButton({required bool isIOS}) {
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: context.wellness.primary,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(vertical: 16),
          onPressed: _isLoading ? null : () => _showMemberAuthSheet(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.envelope_fill,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 10),
              Text(
                '이메일로 회원등록',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : () => _showMemberAuthSheet(),
        icon: const Icon(Icons.email_outlined, color: Colors.white),
        label: Text(
          '이메일로 회원등록',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: context.wellness.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerLoginButton({required bool isIOS}) {
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: context.wellness.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(vertical: 16),
          onPressed: _isLoading ? null : _showTrainerLoginSheet,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.person_badge_plus,
                color: context.wellness.primaryDark,
                size: 21,
              ),
              const SizedBox(width: 10),
              Text(
                '트레이너 ID로 로그인',
                style: GoogleFonts.outfit(
                  color: context.wellness.primaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _showTrainerLoginSheet,
        icon: Icon(Icons.badge_outlined, color: context.wellness.primaryDark),
        label: Text(
          '트레이너 ID로 로그인',
          style: GoogleFonts.outfit(
            color: context.wellness.primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.wellness.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerGuestButton({required bool isIOS}) {
    if (isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 8),
        onPressed: _isLoading ? null : _handleTrainerGuestMode,
        child: Text(
          '트레이너 게스트로 시작',
          style: GoogleFonts.outfit(
            color: context.wellness.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: _isLoading ? null : _handleTrainerGuestMode,
      child: Text(
        '트레이너 게스트로 시작',
        style: GoogleFonts.outfit(
          color: context.wellness.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
