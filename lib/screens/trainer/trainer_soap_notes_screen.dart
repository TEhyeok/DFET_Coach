import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/soap_note.dart';
import '../../state/app_state.dart';
import '../../state/soap_note_state.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/app_card.dart';
import '../../widgets/trainer_widget_label.dart';

enum _LeftPaneMode { members, notes }

const _nativeSoapWorkspaceChannel = MethodChannel('dfet/native_soap_workspace');

class TrainerSoapNotesScreen extends ConsumerStatefulWidget {
  const TrainerSoapNotesScreen({super.key});

  @override
  ConsumerState<TrainerSoapNotesScreen> createState() =>
      _TrainerSoapNotesScreenState();
}

class _TrainerSoapNotesScreenState
    extends ConsumerState<TrainerSoapNotesScreen> {
  String? _selectedId;
  String _query = '';
  _LeftPaneMode _leftPaneMode = _LeftPaneMode.members;
  bool _editorDirty = false;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(soapNotesProvider);

    return notesAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, __) => const Center(
        child: Text('SOAP 노트를 불러올 수 없습니다', style: AppTextStyles.body),
      ),
      data: (notes) {
        final selected = _selectedNote(notes);
        final filteredNotes = _filteredNotes(notes);
        final memberSummaries = _buildMemberSummaries(filteredNotes);
        final isTablet = ResponsiveLayout.isTablet(context);

        if (isTablet) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: _SoapLeftPane(
                    mode: _leftPaneMode,
                    notes: filteredNotes,
                    members: memberSummaries,
                    selectedId: _selectedId,
                    query: _query,
                    onModeChanged: (mode) =>
                        setState(() => _leftPaneMode = mode),
                    onQueryChanged: (value) => setState(() => _query = value),
                    onNew: _requestNewNote,
                    onNativeSession: () => _requestNativeWorkspace(selected),
                    onSelect: _requestSelectNote,
                  ).trainerLabel('TR-FL-SOAP-01'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SoapNoteEditor(
                    key: ValueKey(selected?.id ?? 'new-note'),
                    note: selected,
                    allNotes: notes,
                    onDirtyChanged: (value) {
                      if (_editorDirty != value) {
                        setState(() => _editorDirty = value);
                      }
                    },
                    onSaved: (id) => setState(() {
                      _selectedId = id;
                      _editorDirty = false;
                    }),
                    onDeleted: () => setState(() {
                      _selectedId = notes
                          .where((note) => note.id != _selectedId)
                          .map((note) => note.id)
                          .firstOrNull;
                      _editorDirty = false;
                    }),
                  ).trainerLabel('TR-FL-SOAP-08'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: ResponsiveLayout.pagePadding(context),
          children: [
            _SoapLeftPane(
              mode: _leftPaneMode,
              notes: filteredNotes,
              members: memberSummaries,
              selectedId: _selectedId,
              query: _query,
              onModeChanged: (mode) => setState(() => _leftPaneMode = mode),
              onQueryChanged: (value) => setState(() => _query = value),
              onNew: _requestNewNote,
              onNativeSession: () => _requestNativeWorkspace(selected),
              onSelect: _requestSelectNote,
              shrinkWrap: true,
            ).trainerLabel('TR-FL-SOAP-01'),
            const SizedBox(height: 16),
            _SoapNoteEditor(
              key: ValueKey(selected?.id ?? 'new-note'),
              note: selected,
              allNotes: notes,
              onDirtyChanged: (value) {
                if (_editorDirty != value) {
                  setState(() => _editorDirty = value);
                }
              },
              onSaved: (id) => setState(() {
                _selectedId = id;
                _editorDirty = false;
              }),
              onDeleted: () => setState(() {
                _selectedId = null;
                _editorDirty = false;
              }),
            ).trainerLabel('TR-FL-SOAP-08'),
          ],
        );
      },
    );
  }

  List<SoapNote> _filteredNotes(List<SoapNote> notes) {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return notes;

    return notes.where((note) {
      final haystack = [
        note.memberName,
        note.memberEmail ?? '',
        note.diagnosis,
        note.bodyRegion,
        note.subjective,
        note.assessment,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  SoapNote? _selectedNote(List<SoapNote> notes) {
    final selectedId = _selectedId;
    if (selectedId == null) return null;

    for (final note in notes) {
      if (note.id == selectedId) return note;
    }

    return null;
  }

  List<_MemberSummary> _buildMemberSummaries(List<SoapNote> notes) {
    final byKey = <String, List<SoapNote>>{};

    for (final note in notes) {
      final key = note.memberId?.isNotEmpty == true
          ? note.memberId!
          : note.memberEmail?.isNotEmpty == true
              ? note.memberEmail!
              : note.memberName;
      byKey.putIfAbsent(key, () => []).add(note);
    }

    final summaries = byKey.values.map((memberNotes) {
      memberNotes.sort((a, b) => b.date.compareTo(a.date));
      final latest = memberNotes.first;
      final previous = memberNotes.length > 1 ? memberNotes[1] : null;
      final painDelta = previous == null
          ? null
          : (latest.painNow ?? latest.painWorst ?? 0) -
              (previous.painNow ?? previous.painWorst ?? 0);

      return _MemberSummary(
        name: latest.memberName,
        email: latest.memberEmail,
        latestNoteId: latest.id,
        latestDate: latest.date,
        noteCount: memberNotes.length,
        riskLevel: latest.riskLevel,
        completion: latest.completionPercent,
        painNow: latest.painNow,
        painDelta: painDelta,
        followUpDate: latest.followUpDate,
        notes: memberNotes,
      );
    }).toList()
      ..sort((a, b) => b.latestDate.compareTo(a.latestDate));

    return summaries;
  }

  Future<void> _requestSelectNote(SoapNote note) async {
    if (!await _confirmDiscardIfNeeded()) return;
    setState(() {
      _selectedId = note.id;
      _editorDirty = false;
    });
  }

  Future<void> _requestNewNote() async {
    if (!await _confirmDiscardIfNeeded()) return;
    setState(() {
      _selectedId = null;
      _editorDirty = false;
    });
  }

  Future<void> _requestNativeWorkspace(SoapNote? selected) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      _showNativeMessage('iPad 필기 모드는 iOS에서 사용할 수 있습니다');
      return;
    }
    if (!await _confirmDiscardIfNeeded()) return;

    try {
      final result = await _nativeSoapWorkspaceChannel
          .invokeMapMethod<String, dynamic>('openSoapWorkspace', {
        'memberName': selected?.memberName ?? '',
        'memberId': selected?.memberId ?? '',
        'memberEmail': selected?.memberEmail ?? '',
        'diagnosis': selected?.diagnosis ?? '',
        'bodyRegion': selected?.bodyRegion ?? '',
        'painNow': selected?.painNow,
        'painSite': selected?.painSite ?? '',
        'riskLevel': selected?.riskLevel ?? 'low',
        'subjective': selected?.subjective ?? '',
        'assessment': selected?.assessment ?? '',
        'treatmentPlan': selected?.treatmentPlan ?? '',
        'homeExercise': selected?.homeExercise ?? '',
        'nextPlan': selected?.nextPlan ?? '',
        'nativeRomEntries': _nativeMetricLabels(selected, 'rom'),
        'nativeMmtEntries': _nativeMetricLabels(selected, 'mmt'),
        'nativeExerciseEntries': _nativeMetricLabels(selected, 'exercise'),
      });
      if (result == null) return;

      final savedId = await _saveNativeSoapNote(result, selected);
      if (!mounted) return;
      setState(() {
        _selectedId = savedId;
        _editorDirty = false;
      });
      _showNativeMessage('iPad 필기 SOAP 노트를 저장했습니다');
    } on PlatformException catch (error) {
      if (mounted) {
        _showNativeMessage(error.message ?? 'iPad 필기 모드를 열 수 없습니다');
      }
    }
  }

  List<String> _nativeMetricLabels(SoapNote? note, String type) {
    if (note == null) return const [];
    return note.effectiveStructured.metrics
        .where((metric) => metric.type == type)
        .map((metric) {
          final side = metric.side.isEmpty ? '' : '${metric.side} ';
          final value = metric.value.isEmpty ? '' : ': ${metric.value}';
          final unit = metric.unit.isEmpty ? '' : ' ${metric.unit}';
          final noteText = metric.note.isEmpty ? '' : ' · ${metric.note}';
          return '$side${metric.label}$value$unit$noteText'.trim();
        })
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<String> _saveNativeSoapNote(
    Map<String, dynamic> result,
    SoapNote? existing,
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
    final painSite = _nativeString(result['painSite']);
    final riskLevel = _nativeString(result['riskLevel']).isEmpty
        ? _riskFromPain(painNow)
        : _nativeString(result['riskLevel']);
    final inkData = _nativeString(result['inkDataBase64']);
    final inkStrokeCount = _nativeInt(result['inkStrokeCount']) ?? 0;
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

    final structured = SoapStructuredData(
      subjective: {
        'chiefComplaint': _nativeString(result['subjective']),
        'painSite': painSite,
        'painNow': painNow,
        'nativeInkDataBase64': inkData,
        'nativeInkStrokeCount': inkStrokeCount,
      },
      objective: {
        'observation': 'iPad Pencil session note',
        'romEntries': romEntries,
        'mmtEntries': mmtEntries,
        'exerciseEntries': exerciseEntries,
      },
      assessment: {
        'problemList': _nativeString(result['assessment']),
        'riskLevel': riskLevel,
      },
      plan: {
        'treatmentPlan': _nativeString(result['treatmentPlan']),
        'homeExercise': _nativeString(result['homeExercise']),
        'nextPlan': _nativeString(result['nextPlan']),
      },
      metrics: metrics,
      workflow: SoapWorkflow(
        status: 'draft',
        completedCategories: [
          SoapCategory.meta.name,
          if (_nativeString(result['subjective']).isNotEmpty ||
              painNow != null ||
              inkStrokeCount > 0)
            SoapCategory.subjective.name,
          if (metrics.isNotEmpty) SoapCategory.objective.name,
          if (_nativeString(result['assessment']).isNotEmpty)
            SoapCategory.assessment.name,
          if (_nativeString(result['treatmentPlan']).isNotEmpty ||
              _nativeString(result['homeExercise']).isNotEmpty ||
              _nativeString(result['nextPlan']).isNotEmpty ||
              exerciseEntries.isNotEmpty)
            SoapCategory.plan.name,
          SoapCategory.sharing.name,
        ],
        riskLevel: riskLevel,
      ),
    );

    final note = SoapNote(
      id: existing?.id ?? const Uuid().v4(),
      trainerId: trainerId,
      trainerName:
          isTrainerGuest ? '트레이너 게스트' : profile?.displayName ?? user?.email,
      memberId: _emptyNativeToNull(result['memberId']),
      memberName: memberName,
      memberEmail: _emptyNativeToNull(result['memberEmail']),
      date: existing?.date ?? now,
      diagnosis: _nativeString(result['diagnosis']),
      bodyRegion: _nativeString(result['bodyRegion']),
      subjective: _nativeString(result['subjective']),
      painSite: painSite,
      painNow: painNow,
      rom: romEntries.join('\n'),
      mmt: mmtEntries.join('\n'),
      assessment: _nativeString(result['assessment']),
      treatmentPlan: _nativeString(result['treatmentPlan']),
      homeExercise: _nativeString(result['homeExercise']),
      nextPlan: _nativeString(result['nextPlan']),
      structured: structured,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (isTrainerGuest) {
      await ref.read(guestTrainerSoapNotesProvider.notifier).upsert(note);
    } else {
      await ref.read(firestoreServiceProvider).saveSoapNote(note);
      ref.invalidate(soapNotesProvider);
    }

    return note.id;
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_editorDirty) return true;

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('저장되지 않은 변경'),
        content: const Text('현재 노트의 변경사항을 버리고 이동할까요?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('버리고 이동'),
          ),
        ],
      ),
    );

    return result == true;
  }

  void _showNativeMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _SoapLeftPane extends StatelessWidget {
  const _SoapLeftPane({
    required this.mode,
    required this.notes,
    required this.members,
    required this.selectedId,
    required this.query,
    required this.onModeChanged,
    required this.onQueryChanged,
    required this.onNew,
    required this.onNativeSession,
    required this.onSelect,
    this.shrinkWrap = false,
  });

  final _LeftPaneMode mode;
  final List<SoapNote> notes;
  final List<_MemberSummary> members;
  final String? selectedId;
  final String query;
  final ValueChanged<_LeftPaneMode> onModeChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNew;
  final VoidCallback onNativeSession;
  final ValueChanged<SoapNote> onSelect;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('트레이너 현황', style: AppTextStyles.h2),
                  ),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: onNew,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.add, size: 17, color: Colors.white),
                        SizedBox(width: 5),
                        Text('새 노트', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: onNativeSession,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.pencil,
                          size: 17,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text('iPad 필기', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CupertinoSlidingSegmentedControl<_LeftPaneMode>(
                groupValue: mode,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                thumbColor: AppColors.brandPrimary,
                children: const {
                  _LeftPaneMode.members: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text('회원 현황', style: TextStyle(color: Colors.white)),
                  ),
                  _LeftPaneMode.notes: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text('노트 목록', style: TextStyle(color: Colors.white)),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) onModeChanged(value);
                },
              ),
              const SizedBox(height: 12),
              CupertinoSearchTextField(
                itemColor: Colors.white54,
                style: const TextStyle(color: Colors.white),
                placeholder: '회원명, 진단, 부위 검색',
                placeholderStyle: const TextStyle(color: Colors.white38),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                onChanged: onQueryChanged,
              ),
            ],
          ),
        ).trainerLabel('TR-FL-SOAP-02'),
        const SizedBox(height: 12),
        if (mode == _LeftPaneMode.members)
          _MemberDashboard(
            members: members,
            onSelectNoteId: (noteId) {
              final note = notes.firstWhere((item) => item.id == noteId);
              onSelect(note);
            },
          ).trainerLabel('TR-FL-SOAP-05')
        else
          _NoteDashboard(
            notes: notes,
            selectedId: selectedId,
            onSelect: onSelect,
          ).trainerLabel('TR-FL-SOAP-06'),
      ],
    );

    if (shrinkWrap) return child;
    return SingleChildScrollView(child: child);
  }
}

class _MemberDashboard extends StatelessWidget {
  const _MemberDashboard({
    required this.members,
    required this.onSelectNoteId,
  });

  final List<_MemberSummary> members;
  final ValueChanged<String> onSelectNoteId;

  @override
  Widget build(BuildContext context) {
    final highRisk =
        members.where((member) => member.riskLevel == 'high').length;
    final due = members.where((member) => member.needsFollowUp).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _MetricBox(label: '회원', value: '${members.length}'),
              const SizedBox(width: 8),
              _MetricBox(label: '고위험', value: '$highRisk'),
              const SizedBox(width: 8),
              _MetricBox(label: '재평가', value: '$due'),
            ],
          ),
        ).trainerLabel('TR-FL-SOAP-05-SUMMARY'),
        const SizedBox(height: 12),
        if (members.isEmpty)
          const AppCard(
            child: Text(
              'SOAP 노트를 작성하면 회원 현황이 자동으로 표시됩니다',
              style: AppTextStyles.body,
            ),
          )
        else
          for (final entry in members.asMap().entries) ...[
            _MemberStatusCard(
              member: entry.value,
              onPressed: () => onSelectNoteId(entry.value.latestNoteId),
            ).trainerLabel('TR-FL-SOAP-05-MEMBER-${entry.key + 1}'),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _NoteDashboard extends StatelessWidget {
  const _NoteDashboard({
    required this.notes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SoapNote> notes;
  final String? selectedId;
  final ValueChanged<SoapNote> onSelect;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const AppCard(
        child: Text('아직 작성된 SOAP 노트가 없습니다', style: AppTextStyles.body),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in notes.asMap().entries) ...[
          _SoapNoteListItem(
            note: entry.value,
            isSelected: entry.value.id == selectedId,
            onPressed: () => onSelect(entry.value),
          ).trainerLabel('TR-FL-SOAP-06-NOTE-${entry.key + 1}'),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 3),
            Text(value, style: AppTextStyles.h2),
          ],
        ),
      ),
    );
  }
}

class _MemberStatusCard extends StatelessWidget {
  const _MemberStatusCard({
    required this.member,
    required this.onPressed,
  });

  final _MemberSummary member;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onPressed,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.name,
                  style: AppTextStyles.h3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _RiskPill(level: member.riskLevel),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            member.email ?? '회원 이메일 미입력',
            style: AppTextStyles.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _MiniPainChart(notes: member.notes),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '최근 ${DateFormat('MM.dd').format(member.latestDate)}',
                  style: AppTextStyles.caption,
                ),
              ),
              Text(
                member.painLabel,
                style: AppTextStyles.caption.copyWith(
                  color: member.painDelta != null && member.painDelta! > 0
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${member.completion}%',
                style: AppTextStyles.caption.copyWith(color: AppColors.info),
              ),
            ],
          ),
          if (member.needsFollowUp) ...[
            const SizedBox(height: 8),
            const _Pill(label: '재평가 필요'),
          ],
        ],
      ),
    );
  }
}

class _MiniPainChart extends StatelessWidget {
  const _MiniPainChart({required this.notes});

  final List<SoapNote> notes;

  @override
  Widget build(BuildContext context) {
    final values = notes.reversed
        .map((note) => (note.painNow ?? note.painWorst)?.toDouble())
        .whereType<double>()
        .toList();

    return SizedBox(
      height: 38,
      width: double.infinity,
      child: CustomPaint(
        painter: _MiniPainPainter(values),
      ),
    );
  }
}

class _MiniPainPainter extends CustomPainter {
  const _MiniPainPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height - 1),
        Offset(size.width, size.height - 1), bgPaint);

    if (values.isEmpty) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), bgPaint);
      return;
    }

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : index * size.width / (values.length - 1);
      final y = size.height - (values[index].clamp(0, 10) / 10 * size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniPainPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _SoapNoteListItem extends StatelessWidget {
  const _SoapNoteListItem({
    required this.note,
    required this.isSelected,
    required this.onPressed,
  });

  final SoapNote note;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.16)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary.withValues(alpha: 0.68)
                : AppColors.bgStroke,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.memberName,
                    style: AppTextStyles.h3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('MM.dd').format(note.date),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              note.diagnosis.isEmpty ? '진단/이슈 미입력' : note.diagnosis,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Pill(label: _visitTypeLabel(note.visitType)),
                const SizedBox(width: 6),
                _RiskPill(level: note.riskLevel),
                const SizedBox(width: 6),
                _Pill(label: '${note.completionPercent}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoapNoteEditor extends ConsumerStatefulWidget {
  const _SoapNoteEditor({
    super.key,
    required this.note,
    required this.allNotes,
    required this.onDirtyChanged,
    required this.onSaved,
    required this.onDeleted,
  });

  final SoapNote? note;
  final List<SoapNote> allNotes;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_SoapNoteEditor> createState() => _SoapNoteEditorState();
}

class _SoapNoteEditorState extends ConsumerState<_SoapNoteEditor> {
  final _memberName = TextEditingController();
  final _memberId = TextEditingController();
  final _memberEmail = TextEditingController();
  final _diagnosis = TextEditingController();
  final _bodyRegion = TextEditingController();
  final _chiefComplaint = TextEditingController();
  final _onsetMechanism = TextEditingController();
  final _aggravatingFactors = TextEditingController();
  final _easingFactors = TextEditingController();
  final _painSite = TextEditingController();
  final _painPattern = TextEditingController();
  final _observation = TextEditingController();
  final _palpation = TextEditingController();
  final _neurologicalTests = TextEditingController();
  final _specialTests = TextEditingController();
  final _functionalTests = TextEditingController();
  final _problemList = TextEditingController();
  final _clinicalJudgement = TextEditingController();
  final _shortTermGoal = TextEditingController();
  final _longTermGoal = TextEditingController();
  final _treatmentPlan = TextEditingController();
  final _homeExercise = TextEditingController();
  final _nextPlan = TextEditingController();

  final List<_MetricDraft> _metricDrafts = [];

  DateTime _date = DateTime.now();
  DateTime? _followUpDate;
  String _visitType = 'initial';
  String _setting = 'field';
  String _caseStatus = 'active';
  String _riskLevel = 'low';
  SoapCategory _selectedCategory = SoapCategory.meta;
  double _painNow = 0;
  double _painBest = 0;
  double _painWorst = 0;
  bool _hasPainNow = false;
  bool _hasPainBest = false;
  bool _hasPainWorst = false;
  bool _isSharedWithMember = true;
  bool _isSaving = false;
  bool _isDirty = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _load(widget.note);
  }

  @override
  void didUpdateWidget(covariant _SoapNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note?.id != widget.note?.id) {
      _load(widget.note);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _memberName,
      _memberId,
      _memberEmail,
      _diagnosis,
      _bodyRegion,
      _chiefComplaint,
      _onsetMechanism,
      _aggravatingFactors,
      _easingFactors,
      _painSite,
      _painPattern,
      _observation,
      _palpation,
      _neurologicalTests,
      _specialTests,
      _functionalTests,
      _problemList,
      _clinicalJudgement,
      _shortTermGoal,
      _longTermGoal,
      _treatmentPlan,
      _homeExercise,
      _nextPlan,
    ]) {
      controller.dispose();
    }
    for (final draft in _metricDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _load(SoapNote? note) {
    final structured = note?.effectiveStructured;
    final subjective = structured?.subjective ?? const <String, dynamic>{};
    final objective = structured?.objective ?? const <String, dynamic>{};
    final assessment = structured?.assessment ?? const <String, dynamic>{};
    final plan = structured?.plan ?? const <String, dynamic>{};

    _memberName.text = note?.memberName ?? '';
    _memberId.text = note?.memberId ?? '';
    _memberEmail.text = note?.memberEmail ?? '';
    _diagnosis.text = note?.diagnosis ?? '';
    _bodyRegion.text = note?.bodyRegion ?? '';
    _chiefComplaint.text =
        _asString(subjective['chiefComplaint'], fallback: note?.subjective);
    _onsetMechanism.text = _asString(subjective['onsetMechanism']);
    _aggravatingFactors.text = _asString(subjective['aggravatingFactors']);
    _easingFactors.text = _asString(subjective['easingFactors']);
    _painSite.text =
        _asString(subjective['painSite'], fallback: note?.painSite);
    _painPattern.text =
        _asString(subjective['painPattern'], fallback: note?.painPattern);
    _observation.text =
        _asString(objective['observation'], fallback: note?.observation);
    _palpation.text = _asString(objective['palpation']);
    _neurologicalTests.text = _asString(objective['neurologicalTests'],
        fallback: note?.neurologicalTests);
    _specialTests.text =
        _asString(objective['specialTests'], fallback: note?.specialTests);
    _functionalTests.text = _asString(objective['functionalTests'],
        fallback: note?.functionalTests);
    _problemList.text =
        _asString(assessment['problemList'], fallback: note?.assessment);
    _clinicalJudgement.text = _asString(assessment['clinicalJudgement']);
    _shortTermGoal.text =
        _asString(assessment['shortTermGoal'], fallback: note?.shortTermGoal);
    _longTermGoal.text =
        _asString(assessment['longTermGoal'], fallback: note?.longTermGoal);
    _treatmentPlan.text =
        _asString(plan['treatmentPlan'], fallback: note?.treatmentPlan);
    _homeExercise.text =
        _asString(plan['homeExercise'], fallback: note?.homeExercise);
    _nextPlan.text = _asString(plan['nextPlan'], fallback: note?.nextPlan);
    _date = note?.date ?? DateTime.now();
    _followUpDate = structured?.workflow.followUpDate;
    _visitType = note?.visitType ?? 'initial';
    _setting = note?.setting ?? 'field';
    _caseStatus = note?.caseStatus ?? 'active';
    _riskLevel = structured?.workflow.riskLevel ?? note?.riskLevel ?? 'low';
    _isSharedWithMember = note?.isSharedWithMember ?? true;

    final painNow = _asInt(subjective['painNow']) ?? note?.painNow;
    final painBest = _asInt(subjective['painBest']) ?? note?.painBest;
    final painWorst = _asInt(subjective['painWorst']) ?? note?.painWorst;
    _hasPainNow = painNow != null;
    _hasPainBest = painBest != null;
    _hasPainWorst = painWorst != null;
    _painNow = (painNow ?? 0).clamp(0, 10).toDouble();
    _painBest = (painBest ?? 0).clamp(0, 10).toDouble();
    _painWorst = (painWorst ?? 0).clamp(0, 10).toDouble();

    for (final draft in _metricDrafts) {
      draft.dispose();
    }
    _metricDrafts
      ..clear()
      ..addAll(
        (structured?.metrics ?? const <SoapMetric>[])
            .map((metric) => _MetricDraft.fromMetric(metric, _markDirty)),
      );

    _selectedCategory = SoapCategory.meta;
    _setDirty(false);
  }

  @override
  Widget build(BuildContext context) {
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepper(),
        const SizedBox(height: 14),
        _buildSelectedCategory(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;

        return GestureDetector(
          onTap: _dismissKeyboard,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize:
                  hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
              children: [
                _buildHeader(),
                if (hasBoundedHeight)
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: form,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    child: form,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final completion = _completionPercent();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _memberName.text.trim().isEmpty
                      ? (_isEditing ? '노트 수정' : '새 SOAP 노트')
                      : _memberName.text.trim(),
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(label: DateFormat('yyyy.MM.dd').format(_date)),
                    _Pill(label: '$completion% 완료'),
                    _RiskPill(level: _riskLevel),
                    if (_isDirty) const _Pill(label: '미저장'),
                    if (_isSharedWithMember) const _Pill(label: '회원 공유'),
                  ],
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onPressed: _dismissKeyboard,
            child: const Icon(
              Icons.keyboard_hide_outlined,
              color: Colors.white54,
              size: 22,
            ),
          ),
          if (_isEditing)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onPressed: _isSaving ? null : _confirmDelete,
              child: const Icon(
                CupertinoIcons.delete,
                color: AppColors.danger,
                size: 22,
              ),
            ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.brandPrimary,
            borderRadius: BorderRadius.circular(12),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    ).trainerLabel('TR-FL-SOAP-09');
  }

  Widget _buildStepper() {
    return CupertinoSlidingSegmentedControl<SoapCategory>(
      groupValue: _selectedCategory,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      thumbColor: AppColors.brandPrimary,
      children: {
        for (final category in SoapCategory.values)
          category: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              _categoryLabel(category),
              style: TextStyle(
                color: category == _selectedCategory
                    ? Colors.white
                    : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      },
      onValueChanged: (category) {
        if (category != null) {
          setState(() => _selectedCategory = category);
        }
      },
    ).trainerLabel('TR-FL-SOAP-10');
  }

  Widget _buildSelectedCategory() {
    switch (_selectedCategory) {
      case SoapCategory.meta:
        return _buildMetaSection();
      case SoapCategory.subjective:
        return _buildSubjectiveSection();
      case SoapCategory.objective:
        return _buildObjectiveSection();
      case SoapCategory.assessment:
        return _buildAssessmentSection();
      case SoapCategory.plan:
        return _buildPlanSection();
      case SoapCategory.sharing:
        return _buildSharingSection();
    }
  }

  Widget _buildMetaSection() {
    return _section(
      '기본정보',
      children: [
        _fieldGrid([
          _field('회원명', _memberName, placeholder: '예: 김회원'),
          _field('회원 UID', _memberId, placeholder: '회원 앱 계정 UID'),
          _field('회원 이메일', _memberEmail, placeholder: 'member@email.com'),
          _field('진단/이슈', _diagnosis, placeholder: '예: low back pain'),
          _field('부위', _bodyRegion, placeholder: '예: lumbar, knee, shoulder'),
        ]),
        const SizedBox(height: 12),
        _fieldGrid([
          _segmented(
            label: 'Visit type',
            groupValue: _visitType,
            values: const {
              'initial': 'Initial',
              're_eval': 'Re-eval',
              'rtp': 'RTP',
            },
            onChanged: (value) => setState(() {
              _visitType = value;
              _markDirty();
            }),
          ),
          _segmented(
            label: 'Setting',
            groupValue: _setting,
            values: const {
              'field': 'Field',
              'sideline': 'Sideline',
              'clinic': 'Clinic',
            },
            onChanged: (value) => setState(() {
              _setting = value;
              _markDirty();
            }),
          ),
          _segmented(
            label: '상태',
            groupValue: _caseStatus,
            values: const {
              'active': '진행',
              'monitoring': '관찰',
              'closed': '종결',
            },
            onChanged: (value) => setState(() {
              _caseStatus = value;
              _markDirty();
            }),
          ),
        ]),
      ],
    );
  }

  Widget _buildSubjectiveSection() {
    return _section(
      'S. 주관적 정보',
      children: [
        _field(
          'Chief complaint / History',
          _chiefComplaint,
          minLines: 4,
          placeholder: '주호소, 병력, 생활 패턴',
        ),
        const SizedBox(height: 12),
        _fieldGrid([
          _field('Onset / Mechanism', _onsetMechanism, minLines: 3),
          _field('Aggravating factors', _aggravatingFactors, minLines: 3),
          _field('Easing factors', _easingFactors, minLines: 3),
          _field('Pain site', _painSite),
          _field('Pain pattern', _painPattern),
        ]),
        const SizedBox(height: 14),
        _painSlider(
          label: '현재 통증',
          value: _painNow,
          enabled: _hasPainNow,
          onEnabledChanged: (value) => setState(() {
            _hasPainNow = value;
            _markDirty();
          }),
          onChanged: (value) => setState(() {
            _painNow = value;
            _hasPainNow = true;
            _markDirty();
          }),
        ),
        _painSlider(
          label: '최저 통증',
          value: _painBest,
          enabled: _hasPainBest,
          onEnabledChanged: (value) => setState(() {
            _hasPainBest = value;
            _markDirty();
          }),
          onChanged: (value) => setState(() {
            _painBest = value;
            _hasPainBest = true;
            _markDirty();
          }),
        ),
        _painSlider(
          label: '최고 통증',
          value: _painWorst,
          enabled: _hasPainWorst,
          onEnabledChanged: (value) => setState(() {
            _hasPainWorst = value;
            _riskLevel = _riskFromPain(value ? _painWorst.round() : null);
            _markDirty();
          }),
          onChanged: (value) => setState(() {
            _painWorst = value;
            _hasPainWorst = true;
            _riskLevel = _riskFromPain(value.round());
            _markDirty();
          }),
        ),
      ],
    );
  }

  Widget _buildObjectiveSection() {
    return _section(
      'O. 객관적 정보',
      children: [
        _fieldGrid([
          _field('Observation', _observation, minLines: 3),
          _field('Palpation', _palpation, minLines: 3),
        ]),
        const SizedBox(height: 14),
        _metricTable(type: 'rom', title: 'ROM', unit: 'deg'),
        const SizedBox(height: 14),
        _metricTable(type: 'mmt', title: 'MMT', unit: 'grade'),
        const SizedBox(height: 14),
        _fieldGrid([
          _field('Neurological tests', _neurologicalTests, minLines: 3),
          _field('Special tests', _specialTests, minLines: 3),
          _field('Functional tests', _functionalTests, minLines: 3),
        ]),
        const SizedBox(height: 14),
        _metricTable(type: 'test', title: '검사/기능 지표', unit: 'score'),
      ],
    );
  }

  Widget _buildAssessmentSection() {
    return _section(
      'A. 평가',
      children: [
        _fieldGrid([
          _field('Problem list', _problemList, minLines: 4),
          _field('Clinical judgement', _clinicalJudgement, minLines: 4),
        ]),
        const SizedBox(height: 14),
        _segmented(
          label: 'Risk level',
          groupValue: _riskLevel,
          values: const {
            'low': '낮음',
            'medium': '중간',
            'high': '높음',
          },
          onChanged: (value) => setState(() {
            _riskLevel = value;
            _markDirty();
          }),
        ),
        const SizedBox(height: 14),
        _fieldGrid([
          _field('Short-term goal', _shortTermGoal, minLines: 3),
          _field('Long-term goal', _longTermGoal, minLines: 3),
        ]),
      ],
    );
  }

  Widget _buildPlanSection() {
    return _section(
      'P. 계획',
      children: [
        _field('Treatment plan', _treatmentPlan, minLines: 4),
        const SizedBox(height: 12),
        _fieldGrid([
          _field('Home exercise', _homeExercise, minLines: 3),
          _field('Next session', _nextPlan, minLines: 3),
        ]),
        const SizedBox(height: 14),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _pickFollowUpDate,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.calendar,
                    color: AppColors.info, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _followUpDate == null
                        ? '재평가일 선택'
                        : '재평가일 ${DateFormat('yyyy.MM.dd').format(_followUpDate!)}',
                    style: AppTextStyles.h3,
                  ),
                ),
                if (_followUpDate != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() {
                      _followUpDate = null;
                      _markDirty();
                    }),
                    child: const Icon(CupertinoIcons.xmark_circle_fill,
                        color: Colors.white38),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharingSection() {
    return _section(
      '공유 및 요약',
      children: [
        _shareToggle(),
        const SizedBox(height: 16),
        _SoapSummaryReport(
          subjective: _chiefComplaint.text,
          objective: _observation.text,
          assessment: _problemList.text,
          plan: _treatmentPlan.text,
          metrics: _metricDrafts.map((draft) => draft.toMetric()).toList(),
        ),
      ],
    );
  }

  Widget _section(String title, {required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(title, style: AppTextStyles.h2),
            const Spacer(),
            Text(
              '${_completionPercent()}% 완료',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ).trainerLabel('TR-FL-SOAP-SECTION-$title');
  }

  Widget _fieldGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(
                  width: columns == 1 ? constraints.maxWidth : width,
                  child: child),
          ],
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int minLines = 1,
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 7),
        CupertinoTextField(
          controller: controller,
          minLines: minLines,
          maxLines: minLines == 1 ? 1 : null,
          padding: const EdgeInsets.all(12),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          placeholder: placeholder,
          placeholderStyle: const TextStyle(color: Colors.white30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          onChanged: (_) => setState(_markDirty),
        ),
      ],
    ).trainerLabel('TR-FL-SOAP-FIELD-$label');
  }

  Widget _segmented({
    required String label,
    required String groupValue,
    required Map<String, String> values,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 7),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: groupValue,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          thumbColor: AppColors.brandPrimary,
          children: {
            for (final entry in values.entries)
              entry.key: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color:
                        groupValue == entry.key ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          },
          onValueChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    ).trainerLabel('TR-FL-SOAP-SEG-$label');
  }

  Widget _painSlider({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.h3)),
              Text(
                enabled ? value.round().toString() : '미입력',
                style: AppTextStyles.h3.copyWith(color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 10),
              CupertinoSwitch(
                value: enabled,
                activeTrackColor: AppColors.brandPrimary,
                onChanged: onEnabledChanged,
              ),
            ],
          ),
          if (enabled)
            CupertinoSlider(
              min: 0,
              max: 10,
              divisions: 10,
              value: value,
              activeColor: AppColors.brandPrimary,
              onChanged: onChanged,
            ),
        ],
      ),
    ).trainerLabel('TR-FL-SOAP-PAIN-$label');
  }

  Widget _metricTable({
    required String type,
    required String title,
    required String unit,
  }) {
    final drafts = _metricDrafts.where((draft) => draft.type == type).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.h3)),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                color: AppColors.info.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => setState(() {
                  _metricDrafts.add(
                    _MetricDraft(type: type, unit: unit, onChanged: _markDirty),
                  );
                  _markDirty();
                }),
                child: const Text(
                  '행 추가',
                  style: TextStyle(color: AppColors.info, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (drafts.isEmpty)
            Text('$title 항목이 없습니다', style: AppTextStyles.bodySmall)
          else
            for (final draft in drafts) ...[
              _MetricDraftRow(
                draft: draft,
                onDelete: () => setState(() {
                  _metricDrafts.remove(draft);
                  draft.dispose();
                  _markDirty();
                }),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    ).trainerLabel('TR-FL-SOAP-METRIC-$title');
  }

  Widget _shareToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.eye, color: AppColors.info, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('회원 앱에 공유', style: AppTextStyles.h3),
                SizedBox(height: 2),
                Text(
                  '회원 UID 또는 이메일이 일치하면 회원 화면에서 읽을 수 있습니다',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: _isSharedWithMember,
            activeTrackColor: AppColors.brandPrimary,
            onChanged: (value) => setState(() {
              _isSharedWithMember = value;
              _markDirty();
            }),
          ),
        ],
      ),
    ).trainerLabel('TR-FL-SOAP-SHARE-TOGGLE');
  }

  Future<void> _pickFollowUpDate() async {
    final initial =
        _followUpDate ?? DateTime.now().add(const Duration(days: 7));
    var selected = initial;

    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => Container(
        height: 320,
        color: AppColors.bgCard,
        child: Column(
          children: [
            Row(
              children: [
                CupertinoButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                CupertinoButton(
                  child: const Text('선택'),
                  onPressed: () => Navigator.pop(context, selected),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                minimumYear: DateTime.now().year - 1,
                maximumYear: DateTime.now().year + 2,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _followUpDate = result;
        _markDirty();
      });
    }
  }

  Future<void> _save() async {
    _dismissKeyboard();
    if (_memberName.text.trim().isEmpty) {
      _showMessage('회원명을 입력해주세요');
      setState(() => _selectedCategory = SoapCategory.meta);
      return;
    }

    final user = ref.read(currentUserProvider);
    final isTrainerGuest = ref.read(isTrainerGuestModeProvider);
    final trainerId = isTrainerGuest ? 'trainer_guest' : user?.uid;
    if (trainerId == null) {
      _showMessage('로그인 정보가 없습니다');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile =
          isTrainerGuest ? null : await ref.read(userProfileProvider.future);
      final now = DateTime.now();
      final existing = widget.note;
      final structured = _buildStructuredData();
      final metrics = structured.metrics;
      final note = SoapNote(
        id: existing?.id ?? const Uuid().v4(),
        trainerId: trainerId,
        trainerName:
            isTrainerGuest ? '트레이너 게스트' : profile?.displayName ?? user?.email,
        memberId: _emptyToNull(_memberId.text),
        memberName: _memberName.text.trim(),
        memberEmail: _emptyToNull(_memberEmail.text),
        date: existing?.date ?? _date,
        visitType: _visitType,
        setting: _setting,
        diagnosis: _diagnosis.text.trim(),
        bodyRegion: _bodyRegion.text.trim(),
        caseStatus: _caseStatus,
        subjective: _chiefComplaint.text.trim(),
        painSite: _painSite.text.trim(),
        painPattern: _painPattern.text.trim(),
        painNow: _hasPainNow ? _painNow.round() : null,
        painBest: _hasPainBest ? _painBest.round() : null,
        painWorst: _hasPainWorst ? _painWorst.round() : null,
        observation: _observation.text.trim(),
        rom: _metricsSummary(metrics, 'rom'),
        mmt: _metricsSummary(metrics, 'mmt'),
        neurologicalTests: _neurologicalTests.text.trim(),
        specialTests: _specialTests.text.trim(),
        functionalTests: _functionalTests.text.trim(),
        assessment: _problemList.text.trim(),
        shortTermGoal: _shortTermGoal.text.trim(),
        longTermGoal: _longTermGoal.text.trim(),
        treatmentPlan: _treatmentPlan.text.trim(),
        homeExercise: _homeExercise.text.trim(),
        nextPlan: _nextPlan.text.trim(),
        isSharedWithMember: _isSharedWithMember,
        structured: structured,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (isTrainerGuest) {
        await ref.read(guestTrainerSoapNotesProvider.notifier).upsert(note);
      } else {
        await ref.read(firestoreServiceProvider).saveSoapNote(note);
        ref.invalidate(soapNotesProvider);
      }
      _setDirty(false);
      widget.onSaved(note.id);
      if (mounted) _showMessage('SOAP 노트를 저장했습니다');
    } catch (_) {
      if (mounted) _showMessage('저장 중 오류가 발생했습니다');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final note = widget.note;
    if (note == null) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('노트 삭제'),
        content: const Text('이 SOAP 노트를 삭제할까요?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      if (ref.read(isTrainerGuestModeProvider)) {
        await ref.read(guestTrainerSoapNotesProvider.notifier).delete(note.id);
      } else {
        await ref.read(firestoreServiceProvider).deleteSoapNote(note.id);
        ref.invalidate(soapNotesProvider);
      }
      _setDirty(false);
      widget.onDeleted();
      if (mounted) _showMessage('삭제했습니다');
    } catch (_) {
      if (mounted) _showMessage('삭제 중 오류가 발생했습니다');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  SoapStructuredData _buildStructuredData() {
    final completed = <String>[];

    if (_memberName.text.trim().isNotEmpty) {
      completed.add(SoapCategory.meta.name);
    }
    if (_chiefComplaint.text.trim().isNotEmpty ||
        _hasPainNow ||
        _painSite.text.trim().isNotEmpty) {
      completed.add(SoapCategory.subjective.name);
    }
    if (_observation.text.trim().isNotEmpty ||
        _metricDrafts.any((draft) => draft.isMeaningful) ||
        _functionalTests.text.trim().isNotEmpty) {
      completed.add(SoapCategory.objective.name);
    }
    if (_problemList.text.trim().isNotEmpty ||
        _shortTermGoal.text.trim().isNotEmpty ||
        _longTermGoal.text.trim().isNotEmpty) {
      completed.add(SoapCategory.assessment.name);
    }
    if (_treatmentPlan.text.trim().isNotEmpty ||
        _homeExercise.text.trim().isNotEmpty ||
        _nextPlan.text.trim().isNotEmpty) {
      completed.add(SoapCategory.plan.name);
    }
    completed.add(SoapCategory.sharing.name);

    return SoapStructuredData(
      subjective: {
        'chiefComplaint': _chiefComplaint.text.trim(),
        'onsetMechanism': _onsetMechanism.text.trim(),
        'aggravatingFactors': _aggravatingFactors.text.trim(),
        'easingFactors': _easingFactors.text.trim(),
        'painSite': _painSite.text.trim(),
        'painPattern': _painPattern.text.trim(),
        'painNow': _hasPainNow ? _painNow.round() : null,
        'painBest': _hasPainBest ? _painBest.round() : null,
        'painWorst': _hasPainWorst ? _painWorst.round() : null,
      },
      objective: {
        'observation': _observation.text.trim(),
        'palpation': _palpation.text.trim(),
        'neurologicalTests': _neurologicalTests.text.trim(),
        'specialTests': _specialTests.text.trim(),
        'functionalTests': _functionalTests.text.trim(),
      },
      assessment: {
        'problemList': _problemList.text.trim(),
        'clinicalJudgement': _clinicalJudgement.text.trim(),
        'riskLevel': _riskLevel,
        'shortTermGoal': _shortTermGoal.text.trim(),
        'longTermGoal': _longTermGoal.text.trim(),
      },
      plan: {
        'treatmentPlan': _treatmentPlan.text.trim(),
        'homeExercise': _homeExercise.text.trim(),
        'nextPlan': _nextPlan.text.trim(),
        'followUpDate': _followUpDate?.millisecondsSinceEpoch,
      },
      metrics: _metricDrafts
          .where((draft) => draft.isMeaningful)
          .map((draft) => draft.toMetric())
          .toList(),
      workflow: SoapWorkflow(
        status: completed.length >= SoapCategory.values.length
            ? 'complete'
            : 'draft',
        completedCategories: completed,
        riskLevel: _riskLevel,
        followUpDate: _followUpDate,
      ),
    );
  }

  int _completionPercent() {
    return ((_completedCategoriesPreview().length /
                SoapCategory.values.length) *
            100)
        .round()
        .clamp(0, 100);
  }

  List<SoapCategory> _completedCategoriesPreview() {
    final categories = <SoapCategory>[];
    if (_memberName.text.trim().isNotEmpty) categories.add(SoapCategory.meta);
    if (_chiefComplaint.text.trim().isNotEmpty ||
        _hasPainNow ||
        _painSite.text.trim().isNotEmpty) {
      categories.add(SoapCategory.subjective);
    }
    if (_observation.text.trim().isNotEmpty ||
        _metricDrafts.any((draft) => draft.isMeaningful) ||
        _functionalTests.text.trim().isNotEmpty) {
      categories.add(SoapCategory.objective);
    }
    if (_problemList.text.trim().isNotEmpty ||
        _shortTermGoal.text.trim().isNotEmpty ||
        _longTermGoal.text.trim().isNotEmpty) {
      categories.add(SoapCategory.assessment);
    }
    if (_treatmentPlan.text.trim().isNotEmpty ||
        _homeExercise.text.trim().isNotEmpty ||
        _nextPlan.text.trim().isNotEmpty) {
      categories.add(SoapCategory.plan);
    }
    categories.add(SoapCategory.sharing);
    return categories;
  }

  void _markDirty() => _setDirty(true);

  void _setDirty(bool value) {
    if (_isDirty == value) return;
    _isDirty = value;
    widget.onDirtyChanged(value);
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  String _metricsSummary(List<SoapMetric> metrics, String type) {
    return metrics
        .where((metric) => metric.type == type)
        .map((metric) {
          final side = metric.side.isEmpty ? '' : '${metric.side} ';
          final value = metric.value.isEmpty ? '' : ': ${metric.value}';
          final unit = metric.unit.isEmpty ? '' : ' ${metric.unit}';
          return '$side${metric.label}$value$unit'.trim();
        })
        .where((value) => value.isNotEmpty)
        .join('\n');
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _MetricDraft {
  _MetricDraft({
    required this.type,
    required this.unit,
    required this.onChanged,
    String label = '',
    String side = '',
    String value = '',
    int? score,
    String note = '',
  })  : labelController = TextEditingController(text: label),
        sideController = TextEditingController(text: side),
        valueController = TextEditingController(text: value),
        scoreController = TextEditingController(text: score?.toString() ?? ''),
        noteController = TextEditingController(text: note) {
    for (final controller in [
      labelController,
      sideController,
      valueController,
      scoreController,
      noteController,
    ]) {
      controller.addListener(onChanged);
    }
  }

  factory _MetricDraft.fromMetric(SoapMetric metric, VoidCallback onChanged) {
    return _MetricDraft(
      type: metric.type,
      unit: metric.unit,
      onChanged: onChanged,
      label: metric.label,
      side: metric.side,
      value: metric.value,
      score: metric.score,
      note: metric.note,
    );
  }

  final String type;
  final String unit;
  final VoidCallback onChanged;
  final TextEditingController labelController;
  final TextEditingController sideController;
  final TextEditingController valueController;
  final TextEditingController scoreController;
  final TextEditingController noteController;

  bool get isMeaningful {
    return labelController.text.trim().isNotEmpty ||
        valueController.text.trim().isNotEmpty ||
        noteController.text.trim().isNotEmpty;
  }

  SoapMetric toMetric() {
    return SoapMetric(
      type: type,
      label: labelController.text.trim(),
      side: sideController.text.trim(),
      value: valueController.text.trim(),
      unit: unit,
      score: int.tryParse(scoreController.text.trim()),
      note: noteController.text.trim(),
    );
  }

  void dispose() {
    for (final controller in [
      labelController,
      sideController,
      valueController,
      scoreController,
      noteController,
    ]) {
      controller.dispose();
    }
  }
}

class _MetricDraftRow extends StatelessWidget {
  const _MetricDraftRow({
    required this.draft,
    required this.onDelete,
  });

  final _MetricDraft draft;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _smallField('항목', draft.labelController),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _smallField('측', draft.sideController),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _smallField('값', draft.valueController),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  child: const Icon(CupertinoIcons.minus_circle_fill,
                      color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallField('점수', draft.scoreController)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _smallField('메모', draft.noteController)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallField(String placeholder, TextEditingController controller) {
    return CupertinoTextField(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      placeholder: placeholder,
      placeholderStyle: const TextStyle(color: Colors.white30),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
    );
  }
}

class _SoapSummaryReport extends StatelessWidget {
  const _SoapSummaryReport({
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.metrics,
  });

  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final List<SoapMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SOAP 요약 리포트', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _SummaryBlock(title: 'S', value: subjective),
          _SummaryBlock(title: 'O', value: objective),
          _SummaryBlock(title: 'A', value: assessment),
          _SummaryBlock(title: 'P', value: plan),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              metrics
                  .map((metric) =>
                      '${metric.type.toUpperCase()} ${metric.label} ${metric.side} ${metric.value} ${metric.unit}')
                  .join('\n'),
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(title, style: AppTextStyles.h3),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'high' => AppColors.danger,
      'medium' => AppColors.warn,
      _ => AppColors.success,
    };
    final label = switch (level) {
      'high' => '고위험',
      'medium' => '중위험',
      _ => '저위험',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: Colors.white60),
      ),
    );
  }
}

class _MemberSummary {
  const _MemberSummary({
    required this.name,
    required this.email,
    required this.latestNoteId,
    required this.latestDate,
    required this.noteCount,
    required this.riskLevel,
    required this.completion,
    required this.painNow,
    required this.painDelta,
    required this.followUpDate,
    required this.notes,
  });

  final String name;
  final String? email;
  final String latestNoteId;
  final DateTime latestDate;
  final int noteCount;
  final String riskLevel;
  final int completion;
  final int? painNow;
  final int? painDelta;
  final DateTime? followUpDate;
  final List<SoapNote> notes;

  bool get needsFollowUp {
    final dueDate = followUpDate;
    if (dueDate != null) {
      return !dueDate.isAfter(DateTime.now());
    }
    return DateTime.now().difference(latestDate).inDays >= 14;
  }

  String get painLabel {
    if (painNow == null) return '통증 미입력';
    if (painDelta == null) return '통증 $painNow';
    if (painDelta == 0) return '통증 $painNow / 변화 없음';
    final sign = painDelta! > 0 ? '+' : '';
    return '통증 $painNow ($sign$painDelta)';
  }
}

String _categoryLabel(SoapCategory category) {
  switch (category) {
    case SoapCategory.meta:
      return '기본';
    case SoapCategory.subjective:
      return 'S';
    case SoapCategory.objective:
      return 'O';
    case SoapCategory.assessment:
      return 'A';
    case SoapCategory.plan:
      return 'P';
    case SoapCategory.sharing:
      return '공유';
  }
}

String _visitTypeLabel(String value) {
  switch (value) {
    case 're_eval':
      return 'Re-eval';
    case 'rtp':
      return 'RTP';
    case 'initial':
    default:
      return 'Initial';
  }
}

String _riskFromPain(int? pain) {
  if (pain == null) return 'low';
  if (pain >= 8) return 'high';
  if (pain >= 5) return 'medium';
  return 'low';
}

String _asString(dynamic value, {String? fallback}) {
  if (value == null) return fallback ?? '';
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
