// DF-007 SoapNoteV2Codec against contracts/fixtures/soap_v2 (TC-DF007-01, -02, -04, -05;
// TC-X-XC-01, -04). Run from the repository root: flutter test test/contracts/
//
// Record mode (commit the output):
//   DFET_RECORD_FIXTURES=1 flutter test test/contracts/soap_v2_fixture_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dfet_coach/models/soap_note_v2.dart';
import 'package:dfet_coach/models/soap_note_v2_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_io.dart';

/// Hand-written inputs (P0 DF-005 fixture contract, rule 4).
const List<String> v2Inputs = [
  'draft_rom_mmt_pain',
  'finalized_no_metrics',
  'forward_compat_unknown_code',
  'pending_member_draft',
  'refs_snapshots_pending_policy',
];

/// Inputs that the codecs write back in record mode (DF-007 flutter_*, DF-009 swift_*).
const List<String> recordedBases = [
  'finalized_no_metrics',
  'draft_rom_mmt_pain',
  'pending_member_draft',
];

/// The metric fields AC-DF-007.1 names.
const List<String> checkedMetricFields = [
  'metricCode',
  'value',
  'unit',
  'side',
  'sourceGrade',
  'joint',
  'motion',
  'activeOrPassive',
  'muscleGroup',
  'note',
];

void main() {
  final fixtures = loadFixtureGroup('soap_v2');
  FixtureFile fixture(String base) =>
      fixtures.firstWhere((f) => f.base == base);

  group('TC-DF007-01 AC-DF-007.1 soap_v2 round trip', () {
    test('the five hand-written v2 inputs are present', () {
      final names = fixtures.map((f) => f.base).toSet();
      expect(names.containsAll(v2Inputs), isTrue, reason: 'found $names');
    });

    for (final f in fixtures) {
      test('${f.id}: fromMap(data) -> toMap(fixture) equals data', () {
        final note = SoapNoteV2Codec.fromMap(f.data);
        final out = note.toMap(target: CodecTarget.fixture);

        expect(structuralDiff(out, f.taggedData), isEmpty);
        expect(note.metrics, hasLength(f.expect['metricCount']));
        expect(
            note.uninterpretableMetricCount, f.expect['uninterpretable'] ?? 0);
        // Every key of the fixtures is a known v2 field with a readable value.
        expect(note.extra, isEmpty);
        // Reading the output again gives the same model.
        final again =
            SoapNoteV2Codec.fromMap(decodeTags(out) as Map<String, dynamic>);
        expect(again, note);
        expect(again.hashCode, note.hashCode);
      });
    }

    test('the checked metric fields come back with the same value and notation',
        () {
      var rows = 0;
      for (final f in fixtures) {
        final written =
            SoapNoteV2Codec.fromMap(f.data).toMap(target: CodecTarget.fixture);
        final inRows = _metricRows(f.taggedData);
        final outRows = _metricRows(written);
        expect(outRows, hasLength(inRows.length), reason: f.id);
        for (var i = 0; i < inRows.length; i++) {
          for (final field in checkedMetricFields) {
            final at = '${f.id} objective.metrics[$i].$field';
            expect(outRows[i].containsKey(field), inRows[i].containsKey(field),
                reason: at);
            expect(structuralDiff(outRows[i][field], inRows[i][field], at),
                isEmpty);
          }
          rows++;
        }
      }
      expect(rows, greaterThanOrEqualTo(5));
    });

    test('mmtGrade value is written as \$int, romDeg value as a bare number',
        () {
      final out = SoapNoteV2Codec.fromMap(fixture('draft_rom_mmt_pain').data)
          .toMap(target: CodecTarget.fixture);
      final rows = _metricRows(out);
      expect(rows[0]['value'], 110);
      expect(rows[1]['value'], {r'$int': 4});
      expect((out['subjective'] as Map)['painNrs'], {r'$int': 4});
    });

    test(
        'pending draft keeps memberUid null, no memberId, painNrs null (not 0)',
        () {
      final note =
          SoapNoteV2Codec.fromMap(fixture('pending_member_draft').data);
      expect(note.memberUid, const Present<String>(null));
      expect(note.memberId, isNull);
      expect(note.pendingMemberId, const Present('fx-pending-001'));
      expect(note.subjective!.painNrs, const Present<int>(null));
      expect(note.createdAt, const SoapTimestamp.server());
      expect(note.objective, isNull);
      final out = note.toMap(target: CodecTarget.fixture);
      expect(out.containsKey('memberUid') && out['memberUid'] == null, isTrue);
      expect(out.containsKey('memberId'), isFalse);
      expect(out.containsKey('objective'), isFalse);
    });

    test('parsed rows report completeness by the catalog (V1-05 §5.2)', () {
      final draft = SoapNoteV2Codec.fromMap(fixture('draft_rom_mmt_pain').data);
      expect(
          draft.metrics
              .whereType<ParsedSoapMetric>()
              .every((m) => m.isComplete),
          isTrue);

      const romNoJoint = ParsedSoapMetric(
        metricCode: MetricCode.romDeg,
        value: 90.0,
        unit: MetricUnit.deg,
        side: Side.left,
        sourceGrade: SourceGrade.trainerObserved,
        motion: Motion.flexion,
        activeOrPassive: ActiveOrPassive.active,
      );
      const mmtOutOfRange = ParsedSoapMetric(
        metricCode: MetricCode.mmtGrade,
        value: 6,
        unit: MetricUnit.grade,
        side: Side.right,
        sourceGrade: SourceGrade.trainerObserved,
        muscleGroup: MuscleGroup.hipAbductors,
      );
      const romSideNone = ParsedSoapMetric(
        metricCode: MetricCode.romDeg,
        value: 90.0,
        unit: MetricUnit.deg,
        side: Side.none,
        sourceGrade: SourceGrade.trainerObserved,
        joint: Joint.hip,
        motion: Motion.flexion,
        activeOrPassive: ActiveOrPassive.active,
      );
      const weightInO = ParsedSoapMetric(
        metricCode: MetricCode.weightKg,
        value: 70.0,
        unit: MetricUnit.kg,
        side: Side.none,
        sourceGrade: SourceGrade.trainerObserved,
      );
      for (final m in [romNoJoint, mmtOutOfRange, romSideNone, weightInO]) {
        expect(m.isComplete, isFalse, reason: '$m');
        expect(m.isInterpretable, isTrue);
      }
    });
  });

  group('TC-DF007-02 AC-DF-007.2 F-SOAP-06.2 unknown values are kept', () {
    test(
        'forward_compat_unknown_code: futureMetricX row is unparsed(raw) and re-encodes as is',
        () {
      final f = fixture('forward_compat_unknown_code');
      final note = SoapNoteV2Codec.fromMap(f.data);

      expect(note.metrics, hasLength(2), reason: 'no row is dropped');
      final unknown = note.metrics[0];
      expect(unknown, isA<UnparsedSoapMetric>());
      expect(unknown.isInterpretable, isFalse);
      expect((unknown as UnparsedSoapMetric).metricCodeWire, 'futureMetricX');
      final dataRows = _metricRows(f.data);
      expect(unknown,
          SoapMetricV2.unparsed(Map<String, Object?>.from(dataRows[0])));

      final known = note.metrics[1];
      expect(known, isA<ParsedSoapMetric>());
      expect((known as ParsedSoapMetric).metricCode, MetricCode.mmtGrade);
      expect(known.value, 3);
      expect(known.value, isA<int>());

      final fixtureRows = _metricRows(note.toMap(target: CodecTarget.fixture));
      expect(structuralDiff(fixtureRows[0], _metricRows(f.taggedData)[0]),
          isEmpty);
      // Firestore target writes the stored row unchanged too.
      final firestoreRows = _metricRows(note.toMap());
      expect(firestoreRows[0], dataRows[0]);
      expect(note.uninterpretableMetricCount, 1);
    });

    test(
        'a known code with an unknown enum, a missing value or a fractional mmtGrade stays unparsed',
        () {
      final base = fixture('draft_rom_mmt_pain');
      final rows = [
        {
          'metricCode': 'romDeg',
          'value': 90.0,
          'unit': 'deg',
          'side': 'diagonal',
          'sourceGrade': 'trainerObserved',
          'joint': 'hip',
          'motion': 'flexion',
          'activeOrPassive': 'active',
        },
        {
          'metricCode': 'mmtGrade',
          'value': 4.5,
          'unit': 'grade',
          'side': 'left',
          'sourceGrade': 'trainerObserved',
          'muscleGroup': 'hipAbductors',
        },
        {
          'metricCode': 'mmtGrade',
          'unit': 'grade',
          'side': 'left',
          'sourceGrade': 'trainerObserved'
        },
        {
          'metricCode': 'romDeg',
          'value': 90.0,
          'unit': 'deg',
          'side': 'left',
          'sourceGrade': 'trainerObserved',
          'joint': 'wing',
          'motion': 'flexion',
          'activeOrPassive': 'active',
        },
      ];
      final data = _withMetrics(base.data, rows);
      final note = SoapNoteV2Codec.fromMap(data);
      expect(note.metrics, hasLength(rows.length));
      expect(
          note.metrics
              .every((m) => m is UnparsedSoapMetric && !m.isInterpretable),
          isTrue);
      expect(_metricRows(note.toMap()), rows);
    });

    test(
        'unknown top-level key, unknown status and a wrongly typed field are kept in extra',
        () {
      final data = {
        ...fixture('finalized_no_metrics').data,
        'status': 'archived',
        'quickNote': 42.0,
        'futureField': {'nested': true},
      };
      final note = SoapNoteV2Codec.fromMap(data);
      expect(note.status, isNull);
      expect(note.quickNote, isNull);
      expect(note.extra, {
        'status': 'archived',
        'quickNote': 42.0,
        'futureField': {'nested': true},
      });
      final fx = note.toMap(target: CodecTarget.fixture);
      expect(fx['status'], 'archived');
      expect(fx['quickNote'], 42.0);
      expect(fx['futureField'], {'nested': true});
    });

    test('unknown keys inside a parsed row and a snapshot are kept', () {
      final f = fixture('refs_snapshots_pending_policy');
      final data = decodeTags(f.taggedData) as Map<String, dynamic>;
      final objective = data['objective'] as Map<String, dynamic>;
      (objective['metrics'] as List)[0]['futureRowKey'] = 'x';
      (objective['snapshots'] as List)[0]['changeStatus'] = 'futureStatus';
      final note = SoapNoteV2Codec.fromMap(data);
      final row = note.metrics.single as ParsedSoapMetric;
      expect(row.extra, {'futureRowKey': 'x'});
      final snapshot = note.objective!.snapshots!.first;
      expect(snapshot.changeStatus, isNull);
      expect(snapshot.extra, {'changeStatus': 'futureStatus'});
      final out = note.toMap(target: CodecTarget.fixture);
      final outObjective = out['objective'] as Map;
      expect((outObjective['metrics'] as List)[0]['futureRowKey'], 'x');
      expect((outObjective['snapshots'] as List)[0]['changeStatus'],
          'futureStatus');
    });

    test(
        'a non-map metrics element is an unparsed row; the Firestore target keeps every row',
        () {
      final f = fixture('draft_rom_mmt_pain');
      final stored = [..._metricRows(f.data), '가상 문자열 행', null];
      final data = _withMetrics(f.data, stored);
      final note = SoapNoteV2Codec.fromMap(data);

      expect(note.metrics, hasLength(4), reason: 'no row is dropped');
      expect(note.metrics.take(2).every((m) => m is ParsedSoapMetric), isTrue);
      expect(note.metrics[2], const SoapMetricV2.unparsed('가상 문자열 행'));
      expect(note.metrics[3], const SoapMetricV2.unparsed(null));
      expect((note.metrics[2] as UnparsedSoapMetric).isMapRow, isFalse);
      expect((note.metrics[2] as UnparsedSoapMetric).metricCodeWire, isNull);
      expect(note.uninterpretableMetricCount, 2);
      expect(note.objective!.extra, isEmpty);

      final firestore = note.toMap()['objective'] as Map;
      expect(firestore['metrics'], stored);
      final fx = note.toMap(target: CodecTarget.fixture);
      expect(SoapNoteV2Codec.fromMap(decodeTags(fx) as Map<String, dynamic>),
          note);
    });

    test('a non-map snapshot element is kept in place for both targets', () {
      final data =
          decodeTags(fixture('refs_snapshots_pending_policy').taggedData)
              as Map<String, dynamic>;
      final objective = data['objective'] as Map<String, dynamic>;
      final snapshots = objective['snapshots'] as List;
      final first = snapshots.first;
      objective['snapshots'] = [first, 7.5, null];

      final note = SoapNoteV2Codec.fromMap(data);
      final read = note.objective!.snapshots!;
      expect(read, hasLength(3));
      expect(read[0].isReadable, isTrue);
      expect(read[1].element, const Present<Object>(7.5));
      expect(read[2].element, const Present<Object>(null));
      expect(read[2].isReadable, isFalse);
      expect(note.objective!.extra, isEmpty);

      final out = (note.toMap()['objective'] as Map)['snapshots'] as List;
      expect(out, hasLength(3));
      expect(out.sublist(1), [7.5, null]);
      final fx = note.toMap(target: CodecTarget.fixture);
      expect(SoapNoteV2Codec.fromMap(decodeTags(fx) as Map<String, dynamic>),
          note);
    });

    test(
        'known nested keys with unreadable values are written to Firestore unchanged',
        () {
      final data = decodeTags(fixture('draft_rom_mmt_pain').taggedData)
          as Map<String, dynamic>;
      (data['subjective'] as Map)['painRegions'] = ['shoulderRight', 3.0];
      (data['objective'] as Map)['refs'] = 'not-a-map';
      (data['plan'] as Map)['homeExercise'] = 12.0;
      final note = SoapNoteV2Codec.fromMap(data);
      expect(note.subjective!.painRegions, isNull);
      expect(note.subjective!.extra, {
        'painRegions': ['shoulderRight', 3.0],
      });

      final firestore = note.toMap();
      expect((firestore['subjective'] as Map)['painRegions'],
          ['shoulderRight', 3.0]);
      expect((firestore['objective'] as Map)['refs'], 'not-a-map');
      expect((firestore['objective'] as Map)['metrics'], hasLength(2));
      expect((firestore['plan'] as Map)['homeExercise'], 12.0);
    });

    test('a v1 document is not decoded as v2', () {
      final legacy = loadFixtureGroup('soap_legacy').first;
      expect(SoapNoteV2Codec.isV2(legacy.data), isFalse);
      expect(() => SoapNoteV2Codec.fromMap(legacy.data), throwsFormatException);
    });
  });

  group('TC-DF007-04 toMap(firestore) keeps the client write whitelist', () {
    test('memberSummaryId, legacy, migratedFrom, diagnosis keys: 0', () {
      final data = {
        ...fixture('refs_snapshots_pending_policy').data,
        'memberSummaryId': 'fx-summary-001',
        'migratedFrom': {'runId': 'fx-run-001', 'schemaVersion': 1},
        'legacy': {
          'metricsRaw': [
            {
              'type': 'ROM',
              'label': '가상 항목',
              'side': '양측',
              'value': '40-45',
              'unit': '도'
            },
          ],
          'diagnosisRaw': '가상 원문(합성)',
          'originalIsShared': true,
          'completedCategories': ['subjective', 'objective'],
        },
        'diagnosis': '가상 자동 채움 문구(합성)',
      };
      final note = SoapNoteV2Codec.fromMap(data);
      expect(note.memberSummaryId, const Present('fx-summary-001'));
      expect(note.migratedFrom, {'runId': 'fx-run-001', 'schemaVersion': 1});
      expect(note.legacy!['diagnosisRaw'], '가상 원문(합성)');
      expect(note.extra.keys, ['diagnosis']);

      const blocked = [
        'memberSummaryId',
        'legacy',
        'migratedFrom',
        'diagnosis'
      ];
      final firestore = note.toMap(target: CodecTarget.firestore);
      expect(blocked.where(firestore.containsKey), isEmpty);
      expect(
          firestore.keys
              .where((k) => !SoapNoteV2Codec.clientWritableKeys.contains(k)),
          isEmpty);
      // The default target is Firestore.
      expect(blocked.where(note.toMap().containsKey), isEmpty);

      // Reading is lossless: the fixture target writes them back.
      final fx = note.toMap(target: CodecTarget.fixture);
      expect(blocked.every(fx.containsKey), isTrue);
      expect(
          structuralDiff(fx['migratedFrom'], {
            'runId': 'fx-run-001',
            'schemaVersion': {r'$int': 1}
          }),
          isEmpty);
    });

    test(
        'Firestore target writes Timestamp, FieldValue.serverTimestamp() and int',
        () {
      final draft =
          SoapNoteV2Codec.fromMap(fixture('draft_rom_mmt_pain').data).toMap();
      expect(draft['schemaVersion'], isA<int>());
      expect(
          draft['sessionDate'],
          Timestamp(
              DateTime.utc(2026, 9, 29, 1).millisecondsSinceEpoch ~/ 1000, 0));
      expect((draft['subjective'] as Map)['painNrs'], allOf(isA<int>(), 4));
      final rows = _metricRows(draft);
      expect(rows[0]['value'], allOf(isA<double>(), 110.0));
      expect(rows[1]['value'], allOf(isA<int>(), 4));

      final pending =
          SoapNoteV2Codec.fromMap(fixture('pending_member_draft').data).toMap();
      expect(pending['createdAt'], FieldValue.serverTimestamp());
      expect(pending['updatedAt'], FieldValue.serverTimestamp());
      expect(pending['inkRevision'], allOf(isA<int>(), 1));
      expect(pending['memberUid'], isNull);
      expect(pending.containsKey('memberUid'), isTrue);
    });

    test('nested unknown keys are not written to Firestore (rules hasOnly)',
        () {
      final data = decodeTags(fixture('draft_rom_mmt_pain').taggedData)
          as Map<String, dynamic>;
      (data['plan'] as Map)['futurePlanKey'] = 'x';
      final note = SoapNoteV2Codec.fromMap(data);
      expect(note.plan!.extra, {'futurePlanKey': 'x'});
      expect(
          (note.toMap()['plan'] as Map).containsKey('futurePlanKey'), isFalse);
      expect(
          (note.toMap(target: CodecTarget.fixture)['plan']
              as Map)['futurePlanKey'],
          'x');
    });
  });

  group('fixture loader', () {
    test(r'a $ key outside data fails (contracts/fixtures/README.md §5)', () {
      final dir = Directory.systemTemp.createTempSync('df007_fixture_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/bad.json')
        ..writeAsStringSync(jsonEncode({
          '_fixture': {
            'id': 'soap_v2/bad',
            'expect': {
              r'$int': 1,
            },
          },
          'path': 'soap_notes/fx',
          'data': <String, Object?>{},
        }));
      expect(() => FixtureFile.load(file), throwsFormatException);
    });
  });

  group('record mode (DF-007): flutter_written_* are the current Dart output',
      () {
    for (final base in recordedBases) {
      test('flutter_written_$base.json', () {
        final input = fixture(base);
        final name = 'flutter_written_$base';
        final envelope = recordedEnvelope(
          name: name,
          description:
              'DF-007 기록 모드: Dart SoapNoteV2Codec이 soap_v2/$base.json의 data를 '
              'fromMap으로 읽고 toMap(target: fixture)로 다시 쓴 결과',
          prdRefs: {...input.prdRefs, 'NFR-07'}.toList(),
          expect: input.expect,
          path: input.path,
          data: SoapNoteV2Codec.fromMap(input.data)
              .toMap(target: CodecTarget.fixture),
        );
        final text = canonicalFixtureJson(envelope);
        final file = fixtureFile('soap_v2/$name.json');
        if (recordMode) file.writeAsStringSync(text);
        expect(file.existsSync(), isTrue, reason: _recordHint);
        expect(file.readAsStringSync(), text, reason: _recordHint);
      });
    }
  });

  group('TC-DF007-05 AC-DF-007.4 NFR-07 cross-client written fixtures', () {
    for (final base in recordedBases) {
      final expected = expectedModels[base]!;

      test('$base.json decodes to the hand-built model', () {
        expect(SoapNoteV2Codec.fromMap(fixture(base).data), expected);
      });

      test('flutter_written_$base.json decodes to the hand-built model', () {
        final file = fixtureFile('soap_v2/flutter_written_$base.json');
        expect(file.existsSync(), isTrue, reason: _recordHint);
        expect(SoapNoteV2Codec.fromMap(FixtureFile.load(file).data), expected);
      });

      // AC-DF-009.6: DF-009 committed swift_written_* and removed the skip branch, so a missing
      // file fails here.
      test('swift_written_$base.json decodes to the hand-built model', () {
        final swift = fixtureFile('soap_v2/swift_written_$base.json');
        expect(swift.existsSync(), isTrue, reason: _swiftRecordHint);
        final written = FixtureFile.load(swift);
        expect(written.writer, 'swift');
        expect(written.path, fixture(base).path);
        final note = SoapNoteV2Codec.fromMap(written.data);
        expect(
          structuralDiff(
            note.toMap(target: CodecTarget.fixture),
            expected.toMap(target: CodecTarget.fixture),
          ),
          isEmpty,
        );
        expect(note, expected);
      });
    }
  });
}

const String _recordHint =
    'Run DFET_RECORD_FIXTURES=1 flutter test test/contracts/soap_v2_fixture_test.dart and commit the output.';

const String _swiftRecordHint =
    'Run DFET_RECORD_FIXTURES=1 swift test --package-path trainer_app/Packages/TrainerCore '
    '--filter SoapNoteV2CodecTests and commit the output (DF-009).';

List<Map<dynamic, dynamic>> _metricRows(Map<dynamic, dynamic> data) {
  // Map rows only; tests with non-map rows read `objective.metrics` directly.
  final objective = data['objective'] as Map?;
  return [
    for (final row in (objective?['metrics'] as List?) ?? const []) row as Map
  ];
}

Map<String, dynamic> _withMetrics(
    Map<String, dynamic> data, List<Object?> rows) {
  final objective = Map<String, dynamic>.from(data['objective'] as Map)
    ..['metrics'] = rows;
  return {...data, 'objective': objective};
}

const ObjectiveRefs _emptyRefs = ObjectiveRefs(
  postureAssessmentIds: [],
  bodyCompositionRecordIds: [],
  circumferenceMeasurementIds: [],
  bodyScanIds: [],
);

/// Dart models built by hand with the same meaning as the three record-mode inputs.
final Map<String, SoapNoteV2> expectedModels = {
  'finalized_no_metrics': SoapNoteV2(
    trainerId: const Present('fx-trainer-001'),
    authorUid: 'fx-trainer-001',
    memberUid: const Present('fx-member-001'),
    memberId: 'fx-member-001',
    pendingMemberId: const Present(null),
    sessionDate: SoapTimestamp.at(DateTime.utc(2026, 9, 28, 1)),
    status: SoapStatus.finalized,
    quickNote: '가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함',
    objective:
        const SoapObjective(metrics: [], refs: _emptyRefs, snapshots: []),
    plan: const SoapPlan(nextSession: '어깨 가동성 운동 이어서 진행', homeExercise: ''),
    legalNature: 'coachingRecord',
    isSharedWithMember: false,
    finalizedAt: SoapTimestamp.at(DateTime.utc(2026, 9, 28, 2)),
    createdAt: SoapTimestamp.at(DateTime.utc(2026, 9, 28, 1, 0, 5)),
    updatedAt: SoapTimestamp.at(DateTime.utc(2026, 9, 28, 2)),
  ),
  'draft_rom_mmt_pain': SoapNoteV2(
    trainerId: const Present('fx-trainer-001'),
    authorUid: 'fx-trainer-001',
    memberUid: const Present('fx-member-001'),
    memberId: 'fx-member-001',
    pendingMemberId: const Present(null),
    sessionDate: SoapTimestamp.at(DateTime.utc(2026, 9, 29, 1)),
    status: SoapStatus.draft,
    quickNote: '가상 회원 A, 팔을 옆으로 들 때 오른쪽 어깨가 불편하다고 말함',
    subjective: const SoapSubjective(
      chiefComplaint: '오른쪽 어깨를 들 때 불편하다고 함',
      painNrs: Present(4),
      painRegions: ['shoulderRight'],
    ),
    objective: const SoapObjective(
      metrics: [
        SoapMetricV2.parsed(
          metricCode: MetricCode.romDeg,
          value: 110.0,
          unit: MetricUnit.deg,
          side: Side.right,
          sourceGrade: SourceGrade.trainerObserved,
          joint: Joint.shoulder,
          motion: Motion.flexion,
          activeOrPassive: ActiveOrPassive.active,
        ),
        SoapMetricV2.parsed(
          metricCode: MetricCode.mmtGrade,
          value: 4,
          unit: MetricUnit.grade,
          side: Side.right,
          sourceGrade: SourceGrade.trainerObserved,
          muscleGroup: MuscleGroup.shoulderAbductors,
          note: '가상 관찰 메모',
        ),
      ],
      refs: _emptyRefs,
      snapshots: [],
    ),
    plan: const SoapPlan(
        nextSession: '어깨 외전 가동성 다시 확인', homeExercise: '벽 짚고 팔 올리기 10회'),
    legalNature: 'coachingRecord',
    isSharedWithMember: false,
    createdAt: SoapTimestamp.at(DateTime.utc(2026, 9, 29, 1, 0, 3)),
    updatedAt: SoapTimestamp.at(DateTime.utc(2026, 9, 29, 1, 40)),
  ),
  'pending_member_draft': SoapNoteV2(
    trainerId: const Present('fx-trainer-001'),
    authorUid: 'fx-trainer-001',
    memberUid: const Present(null),
    pendingMemberId: const Present('fx-pending-001'),
    // 2026-09-30T14:00:00+09:00
    sessionDate: SoapTimestamp.at(DateTime.utc(2026, 9, 30, 5)),
    status: SoapStatus.draft,
    quickNote: '가상 회원 B, 첫 세션. 허리 숙일 때 뻐근하다고 말함',
    inkPath: const Present('soapInk/fx-note-v2-003/1.drawing'),
    inkRevision: 1,
    subjective: const SoapSubjective(painNrs: Present(null), painRegions: []),
    legalNature: 'coachingRecord',
    createdAt: const SoapTimestamp.server(),
    updatedAt: const SoapTimestamp.server(),
  ),
};
