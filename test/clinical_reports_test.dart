import 'package:dfet_coach/models/clinical_reports.dart';
import 'package:dfet_coach/services/clinical_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('미승인 장 보고서는 수치만 유지하고 산정 준비 중으로 파싱한다', () {
    final report = GutReport.fromMap({
      'userId': 'member-1',
      'sampledAt': '2026-08-01T00:00:00Z',
      'reportedAt': '2026-08-02T00:00:00Z',
      'overall': {'score': null, 'status': 'unscored', 'label': '산정 준비 중'},
      'alpha': {
        'shannon': {
          'value': 2.4,
          'score': null,
          'status': 'unscored',
          'referenceMean': 3.1,
        },
      },
      'composition': {
        'phylum': [
          {'name': 'Firmicutes', 'value': 55},
        ],
      },
      'guides': ['통곡물과 채소를 하루 두 끼 이상 유지하세요.'],
    }, 'gut-1');

    expect(report.overall.isScored, isFalse);
    expect(report.overall.label, '산정 준비 중');
    expect(report.alpha['shannon']?.value, 2.4);
    expect(report.alpha['shannon']?.referenceMean, 3.1);
    expect(report.phylum.single.value, 55);
    expect(report.guides, hasLength(1));
  });

  test('부분 혈액 보고서의 패널 완성도와 검토 개수를 유지한다', () {
    final report = BloodReport.fromMap({
      'userId': 'member-1',
      'sampledAt': 1785542400000,
      'reportedAt': 1785628800000,
      'overall': {'score': null, 'status': 'unscored', 'label': '산정 준비 중'},
      'biomarkers': [
        {
          'code': 'ALT',
          'panel': 'liver',
          'value': 24,
          'unit': 'U/L',
          'status': 'review'
        },
      ],
      'panels': {
        'liver': {'score': null, 'status': 'unscored', 'completeness': 0.1667},
      },
      'summary': {'reviewCount': 1},
    }, 'blood-1');

    expect(report.biomarkers, hasLength(1));
    expect(report.panels['liver']?.completeness, closeTo(0.1667, 0.0001));
    expect(report.reviewCount, 1);
  });

  test('통합 스냅샷은 diet 축과 누락 축을 보간 없이 유지한다', () {
    final snapshot = HealthSnapshot.fromMap({
      'userId': 'member-1',
      'asOf': '2026-08-02T00:00:00Z',
      'axes': {'fitness': 80, 'diet': 70, 'gut': null, 'blood': null},
      'missingAxes': ['gut', 'blood'],
      'completeness': 0.5,
      'overallScore': null,
      'label': '산정 준비 중',
      'insights': [],
    }, 'snapshot-1');

    expect(snapshot.axes['diet'], 70);
    expect(snapshot.axes['gut'], isNull);
    expect(snapshot.missingAxes, ['gut', 'blood']);
    expect(snapshot.overallScore, isNull);
  });

  test('기능 플래그 문서가 없으면 임상 기능은 안전하게 비활성화된다', () {
    final flags = AppFeatureFlags.fromMap(null);
    expect(flags.gut, isFalse);
    expect(flags.blood, isFalse);
    expect(flags.insights, isFalse);
  });
}
