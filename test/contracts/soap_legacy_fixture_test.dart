// DF-007 LegacySoapView against contracts/fixtures/soap_legacy (TC-DF007-03, TC-X-XC-03).
// Run from the repository root: flutter test test/contracts/

import 'package:dfet_coach/contracts/generated/vocab.g.dart' show SoapStatus;
import 'package:dfet_coach/models/legacy_soap_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_io.dart';

/// Legacy inputs and their metric counts (P0 DF-005 fixture contract, rule 4 table).
const Map<String, int> legacyInputs = {
  'drawing_data_bytes': 0,
  'flutter_rom_mmt_test_general': 4,
  'native_bridge_label_only': 3,
  'schema_doc_vocab': 3,
  'status_shared_korean': 1,
  'trainer_ios_korean_enum': 5,
};

void main() {
  final fixtures = loadFixtureGroup('soap_legacy');
  LegacySoapView view(String base) =>
      LegacySoapView.fromMap(fixtures.firstWhere((f) => f.base == base).data);

  group(
      'TC-DF007-03 AC-DF-007.3 AC-SOAP-06.2 legacy documents keep every metric',
      () {
    test('the six legacy inputs are present', () {
      expect(fixtures.map((f) => f.base).toSet(), legacyInputs.keys.toSet());
    });

    for (final f in fixtures) {
      test('${f.id}: metrics.length == expect.legacyMetricCount, all 해석 불가',
          () {
        final v = LegacySoapView.fromMap(f.data);
        expect(v.metrics, hasLength(f.expect['legacyMetricCount']));
        expect(v.metrics, hasLength(legacyInputs[f.base]));

        final stored = ((f.data['structured'] as Map)['metrics'] as List);
        for (var i = 0; i < v.metrics.length; i++) {
          final m = v.metrics[i];
          expect(m.interpretation, LegacyMetricInterpretation.uninterpretable);
          expect(m.isInterpretable, isFalse);
          expect(m.displayLabel, '해석 불가');
          // The original row is kept as stored (values are never filled with 0).
          expect(m.raw, stored[i]);
          expect(m.valueText, stored[i]['value']);
        }
      });
    }

    test(
        'legacy notations (ROM, 통증, test, general, ...) are all uninterpretable',
        () {
      final byType = <String, LegacyMetricInterpretation>{
        for (final f in fixtures)
          for (final m in LegacySoapView.fromMap(f.data).metrics)
            m.type!: m.interpretation,
      };
      for (final type in [
        'rom', 'mmt', 'test', 'general', // Flutter editor
        'ROM', '통증', 'MMT', '기능검사', '특수검사', // trainer_ios
        'pain', 'functional', 'specialTest', // schema doc
        'exercise', // native bridge
      ]) {
        expect(byType[type], LegacyMetricInterpretation.uninterpretable,
            reason: type);
      }
    });

    test("workflow.status '작성 중' is kept as legacyStatus", () {
      final v = view('trainer_ios_korean_enum');
      expect(v.legacyStatus, '작성 중');
      expect(v.mappedStatus, SoapStatus.draft);
      expect(v.completedCategories, ['S']);
      expect(v.normalizedCompletedCategories, ['subjective']);
    });

    test('status notations map to v2 status (V1-05 §5.6) and keep the original',
        () {
      expect(view('flutter_rom_mmt_test_general').legacyStatus, 'complete');
      expect(view('flutter_rom_mmt_test_general').mappedStatus,
          SoapStatus.finalized);
      expect(view('schema_doc_vocab').legacyStatus, '완료');
      expect(view('schema_doc_vocab').mappedStatus, SoapStatus.finalized);
      final shared = view('status_shared_korean');
      expect(shared.legacyStatus, '공유됨');
      expect(shared.mappedStatus, SoapStatus.finalized);
      expect(shared.wasShared, isTrue);
      expect(view('native_bridge_label_only').mappedStatus, SoapStatus.draft);
    });

    test(
        'unparsable values stay as text (110-120, 4+) and label-only rows keep their label',
        () {
      final flutter = view('flutter_rom_mmt_test_general');
      expect(flutter.metrics.map((m) => m.valueText),
          containsAll(['110-120', '4+']));
      final bridge = view('native_bridge_label_only');
      expect(bridge.metrics.map((m) => m.label), ['허리 굴곡', '엉덩이 외전', '힙힌지 드릴']);
      expect(bridge.metrics.every((m) => m.valueText.isEmpty), isTrue);
    });

    test(
        'local member- seed has no linked member (MIG-07); inline ink is detected, read only',
        () {
      final bridge = view('native_bridge_label_only');
      expect(bridge.hasLinkedMember, isFalse);
      expect(bridge.hasInlineInk, isTrue);
      expect(view('drawing_data_bytes').hasInlineInk, isTrue);
      expect(view('schema_doc_vocab').hasInlineInk, isFalse);
      expect(view('schema_doc_vocab').hasLinkedMember, isTrue);
      expect(
          view('schema_doc_vocab').sessionDate, DateTime.utc(2026, 9, 22, 1));
    });

    test('a numeric-looking legacy value stays text with no numeric reading',
        () {
      final v = LegacySoapView.fromMap({
        'structured': {
          'metrics': [
            {
              'type': 'rom',
              'label': '가상 어깨 굴곡',
              'side': 'right',
              'value': '120.0',
              'unit': 'deg',
            },
          ],
        },
      });
      final m = v.metrics.single;
      expect(m.isInterpretable, isFalse);
      expect(m.valueText, '120.0');
      expect(m.raw['value'], isA<String>());
    });

    test('no public getter exposes diagnosis (MIG-04)', () {
      final f =
          fixtures.firstWhere((f) => f.base == 'native_bridge_label_only');
      final diagnosis = f.data['diagnosis'] as String;
      expect(diagnosis, isNotEmpty);
      final v = LegacySoapView.fromMap(f.data);
      final exposed = <Object?>[
        v.trainerId,
        v.memberId,
        v.sessionDate,
        v.legacyStatus,
        v.mappedStatus,
        v.wasShared,
        v.completedCategories,
        v.normalizedCompletedCategories,
        v.hasLinkedMember,
        v.hasInlineInk,
        for (final m in v.metrics) m.raw,
        v.toString(),
      ];
      for (final value in exposed) {
        expect('$value', isNot(contains(diagnosis)));
        expect('$value', isNot(contains('diagnosis')));
      }
    });

    test('a non-map row still counts as a metric', () {
      final v = LegacySoapView.fromMap({
        'structured': {
          'metrics': ['가상 문자열 행', null],
        },
      });
      expect(v.metrics, hasLength(2));
      expect(v.metrics.every((m) => m.displayLabel == '해석 불가'), isTrue);
    });
  });
}
