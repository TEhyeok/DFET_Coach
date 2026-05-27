import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../../models/soap_note.dart';
import '../../state/app_state.dart';
import '../../state/soap_note_state.dart';
import '../../theme/tokens.dart';
import '../trainer_widget_label.dart';

class TrainerShell extends ConsumerStatefulWidget {
  const TrainerShell({
    super.key,
    this.autoOpenNativeHome = false,
  });

  final bool autoOpenNativeHome;

  @override
  ConsumerState<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends ConsumerState<TrainerShell> {
  bool _isOpeningNativeTrainerHome = false;
  bool _didAutoOpenNativeTrainerHome = false;

  static const _nativeTrainerHomeChannel =
      MethodChannel('dfet/native_trainer_home');

  @override
  void initState() {
    super.initState();
    _nativeTrainerHomeChannel
        .setMethodCallHandler(_handleNativeTrainerHomeCall);
    if (widget.autoOpenNativeHome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoOpenNativeTrainerHome) return;
        _didAutoOpenNativeTrainerHome = true;
        _openNativeTrainerHome();
      });
    }
  }

  @override
  void dispose() {
    _nativeTrainerHomeChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6670D5), Color(0xFF17235F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF17235F).withValues(alpha: 0.20),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.rectangle_grid_2x2_fill,
                          color: CupertinoColors.white,
                          size: 34,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'D-FET Trainer',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'iPad 세션 보드, Pencil SOAP, 회원 리포트를 SwiftUI 화면으로 엽니다.',
                          style: TextStyle(
                            color: Color(0xB8FFFFFF),
                            fontSize: 16,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ).trainerLabel('TR-FL-SHELL-01'),
                  const SizedBox(height: 18),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isOpeningNativeTrainerHome
                        ? null
                        : _openNativeTrainerHome,
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppleColors.blue,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        _isOpeningNativeTrainerHome ? '여는 중...' : '트레이너 앱 열기',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ).trainerLabel('TR-FL-SHELL-02'),
                  const SizedBox(height: 12),
                  const Text(
                    '기존 Flutter 트레이너 탭은 숨겼고, 트레이너 전용 화면은 iPad 네이티브 디자인으로 통일합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF706A7B),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ).trainerLabel('TR-FL-SHELL-03'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNativeTrainerHome() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (_isOpeningNativeTrainerHome) {
      return;
    }

    setState(() => _isOpeningNativeTrainerHome = true);
    try {
      AppLogger.info('[TrainerShell] 네이티브 트레이너 홈 열기 요청');
      await _nativeTrainerHomeChannel.invokeMethod<void>(
        'openTrainerHome',
        {'initialRoute': 'sessionBoard'},
      );
      AppLogger.info('[TrainerShell] 네이티브 트레이너 홈 닫힘');
    } on PlatformException catch (error) {
      AppLogger.error('[TrainerShell] 네이티브 트레이너 홈 PlatformException', error);
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('트레이너 화면을 열 수 없습니다'),
          content: Text(error.message ?? 'iPad 네이티브 화면 연결 상태를 확인해 주세요.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('[TrainerShell] 네이티브 트레이너 홈 호출 실패', error, stackTrace);
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('트레이너 화면을 열 수 없습니다'),
          content: Text('$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningNativeTrainerHome = false);
      } else {
        _isOpeningNativeTrainerHome = false;
      }
    }
  }

  Future<dynamic> _handleNativeTrainerHomeCall(MethodCall call) async {
    switch (call.method) {
      case 'saveNativeTrainerSoapNote':
        final arguments = call.arguments;
        if (arguments is! Map) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'SOAP 저장 데이터 형식이 올바르지 않습니다',
          );
        }
        return _saveNativeTrainerSoapNote(
          Map<String, dynamic>.from(arguments),
        );
      case 'nativeTrainerLogout':
        return _handleNativeTrainerLogout();
      default:
        throw MissingPluginException('Unknown method ${call.method}');
    }
  }

  Future<Map<String, dynamic>> _handleNativeTrainerLogout() async {
    AppLogger.info('[TrainerShell] 네이티브 트레이너 로그아웃 요청');

    final prefs = ref.read(sharedPreferencesProvider);
    final authService = ref.read(authServiceProvider);
    final trainerGuestMode = ref.read(isTrainerGuestModeProvider.notifier);
    final guestMode = ref.read(isGuestModeProvider.notifier);
    final hasSeenOnboarding = ref.read(hasSeenOnboardingProvider.notifier);
    final currentTabIndex = ref.read(currentTabIndexProvider.notifier);

    currentTabIndex.state = 0;
    hasSeenOnboarding.state = true;
    trainerGuestMode.state = false;
    guestMode.state = false;
    await prefs.setBool('hasSeenOnboarding', true);

    try {
      await authService.signOut();
    } catch (error, stackTrace) {
      AppLogger.warning(
        '[TrainerShell] 네이티브 트레이너 로그아웃 중 Firebase 로그아웃 실패',
        error,
        stackTrace,
      );
    }

    return {'loggedOut': true};
  }

  Future<Map<String, dynamic>> _saveNativeTrainerSoapNote(
    Map<String, dynamic> result,
  ) async {
    final user = ref.read(currentUserProvider);
    final isTrainerGuest = ref.read(isTrainerGuestModeProvider);
    final trainerId = isTrainerGuest ? 'trainer_guest' : user?.uid;
    if (trainerId == null) {
      throw PlatformException(
        code: 'not_authenticated',
        message: '로그인 정보가 없습니다',
      );
    }

    final profile =
        isTrainerGuest ? null : await ref.read(userProfileProvider.future);
    final now = DateTime.now();
    final memberName = _nativeString(result['memberName']).isEmpty
        ? '이름 없음'
        : _nativeString(result['memberName']);
    final painNow = _nativeInt(result['painNow']);
    final bodyRegion = _nativeString(result['bodyRegion']);
    final painSite = _nativeString(result['painSite']).isEmpty
        ? bodyRegion
        : _nativeString(result['painSite']);
    final riskLevel = _normalizeRiskLevel(
      _nativeString(result['riskLevel']),
      painNow,
    );
    final romEntries = _nativeStringList(result['nativeRomEntries']);
    final mmtEntries = _nativeStringList(result['nativeMmtEntries']);
    final exerciseEntries = _nativeStringList(result['nativeExerciseEntries']);
    final metrics = <SoapMetric>[
      for (final entry in romEntries)
        SoapMetric(type: 'rom', label: entry, unit: 'deg'),
      for (final entry in mmtEntries)
        SoapMetric(type: 'mmt', label: entry, unit: 'grade'),
      for (final entry in exerciseEntries)
        SoapMetric(type: 'exercise', label: entry),
    ];
    final subjective = _nativeString(result['subjective']);
    final objective = _nativeString(result['objective']);
    final assessment = _nativeString(result['assessment']);
    final treatmentPlan = _nativeString(result['treatmentPlan']);
    final homeExercise = _nativeString(result['homeExercise']);
    final nextPlan = _nativeString(result['nextPlan']);
    final inkData = _nativeString(result['inkDataBase64']);
    final inkStrokeCount = _nativeInt(result['inkStrokeCount']) ?? 0;

    final structured = SoapStructuredData(
      subjective: {
        'chiefComplaint': subjective,
        'painSite': painSite,
        'painNow': painNow,
        'nativeInkDataBase64': inkData,
        'nativeInkStrokeCount': inkStrokeCount,
      },
      objective: {
        'observation': objective,
        'romEntries': romEntries,
        'mmtEntries': mmtEntries,
        'exerciseEntries': exerciseEntries,
      },
      assessment: {
        'problemList': assessment,
        'riskLevel': riskLevel,
      },
      plan: {
        'treatmentPlan': treatmentPlan,
        'homeExercise': homeExercise,
        'nextPlan': nextPlan,
      },
      metrics: metrics,
      workflow: SoapWorkflow(
        status: 'draft',
        completedCategories: [
          SoapCategory.meta.name,
          if (subjective.isNotEmpty || painNow != null || inkStrokeCount > 0)
            SoapCategory.subjective.name,
          if (objective.isNotEmpty || metrics.isNotEmpty)
            SoapCategory.objective.name,
          if (assessment.isNotEmpty) SoapCategory.assessment.name,
          if (treatmentPlan.isNotEmpty ||
              homeExercise.isNotEmpty ||
              nextPlan.isNotEmpty ||
              exerciseEntries.isNotEmpty)
            SoapCategory.plan.name,
          SoapCategory.sharing.name,
        ],
        riskLevel: riskLevel,
      ),
    );

    final note = SoapNote(
      id: _stableNativeSoapId(result),
      trainerId: trainerId,
      trainerName:
          isTrainerGuest ? '트레이너 게스트' : profile?.displayName ?? user?.email,
      memberId: _emptyNativeToNull(result['memberId']),
      memberName: memberName,
      memberEmail: _emptyNativeToNull(result['memberEmail']),
      date: _nativeDate(result['dateMillis']) ?? now,
      diagnosis: _nativeString(result['diagnosis']),
      bodyRegion: bodyRegion,
      subjective: subjective,
      painSite: painSite,
      painNow: painNow,
      observation: objective,
      rom: romEntries.join('\n'),
      mmt: mmtEntries.join('\n'),
      assessment: assessment,
      treatmentPlan: treatmentPlan,
      homeExercise: homeExercise,
      nextPlan: nextPlan,
      isSharedWithMember: true,
      structured: structured,
      createdAt: _nativeDate(result['createdAtMillis']) ?? now,
      updatedAt: now,
    );

    if (isTrainerGuest) {
      await ref.read(guestTrainerSoapNotesProvider.notifier).upsert(note);
      AppLogger.info('[TrainerShell] 게스트 SOAP 노트 로컬 저장: ${note.id}');
      return {
        'id': note.id,
        'synced': false,
        'storage': 'guest',
      };
    }

    await ref.read(firestoreServiceProvider).saveSoapNote(note);
    ref.invalidate(soapNotesProvider);
    AppLogger.info('[TrainerShell] SOAP 노트 Firestore 동기화 성공: ${note.id}');
    return {
      'id': note.id,
      'synced': true,
      'storage': 'firestore',
    };
  }
}

String _nativeString(dynamic value) {
  return value?.toString().trim() ?? '';
}

int? _nativeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<String> _nativeStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _emptyNativeToNull(dynamic value) {
  final text = _nativeString(value);
  return text.isEmpty ? null : text;
}

DateTime? _nativeDate(dynamic value) {
  final millis = _nativeInt(value);
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

String _normalizeRiskLevel(String value, int? pain) {
  switch (value) {
    case 'high':
    case '고위험':
      return 'high';
    case 'medium':
    case '주의':
    case '재평가':
      return 'medium';
    case 'low':
    case '안정':
      return 'low';
    default:
      if (pain == null) return 'low';
      if (pain >= 8) return 'high';
      if (pain >= 5) return 'medium';
      return 'low';
  }
}

String _stableNativeSoapId(Map<String, dynamic> result) {
  final existing = _nativeString(result['id']);
  if (existing.isNotEmpty) return existing;

  final memberKey = _nativeString(result['memberId']).isNotEmpty
      ? _nativeString(result['memberId'])
      : _nativeString(result['memberName']);
  final dateMillis = _nativeInt(result['dateMillis']);
  if (memberKey.isEmpty || dateMillis == null) {
    return const Uuid().v4();
  }
  final safeMemberKey = memberKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return 'native_${safeMemberKey}_$dateMillis';
}
