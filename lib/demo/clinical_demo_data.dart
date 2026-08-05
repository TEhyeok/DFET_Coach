import '../models/clinical_reports.dart';
import '../models/user_profile.dart';

final clinicalDemoProfile = UserProfile(
  uid: 'demo-trainer',
  email: 'demo@dfet.co.kr',
  displayName: 'D-FET 데모',
  provider: 'demo',
  createdAt: DateTime(2026, 1, 1),
  lastLoginAt: DateTime(2026, 8, 5),
  careType: CareType.both,
  careTypeVersion: 1,
  careTypeConfirmedAt: DateTime(2026, 8, 5),
  isOnboardingComplete: true,
  isApproved: true,
  role: 'trainer',
);

const _gutAlphaLatest = <String, MetricAssessment>{
  'shannon': MetricAssessment(
    value: 3.42,
    score: 88,
    status: 'scored',
    label: '양호',
    referenceRange: ReferenceRange(lower: 2.5, upper: 4.5),
  ),
  'simpson': MetricAssessment(
    value: 0.91,
    score: 92,
    status: 'scored',
    label: '양호',
    referenceRange: ReferenceRange(lower: 0.75, upper: 1),
  ),
  'chao1': MetricAssessment(
    value: 327,
    score: 82,
    status: 'scored',
    label: '적정',
    referenceRange: ReferenceRange(lower: 220, upper: 420),
  ),
  'observedOtus': MetricAssessment(
    value: 268,
    score: 84,
    status: 'scored',
    label: '적정',
    referenceRange: ReferenceRange(lower: 180, upper: 360),
  ),
};

const _gutAlphaPrevious = <String, MetricAssessment>{
  'shannon': MetricAssessment(
    value: 2.91,
    score: 75,
    status: 'scored',
    label: '보통',
    referenceRange: ReferenceRange(lower: 2.5, upper: 4.5),
  ),
  'simpson': MetricAssessment(
    value: 0.84,
    score: 78,
    status: 'scored',
    label: '보통',
    referenceRange: ReferenceRange(lower: 0.75, upper: 1),
  ),
  'chao1': MetricAssessment(
    value: 274,
    score: 73,
    status: 'scored',
    label: '보통',
    referenceRange: ReferenceRange(lower: 220, upper: 420),
  ),
  'observedOtus': MetricAssessment(
    value: 219,
    score: 70,
    status: 'scored',
    label: '보통',
    referenceRange: ReferenceRange(lower: 180, upper: 360),
  ),
};

const _phylumLatest = <TaxonAbundance>[
  TaxonAbundance(name: 'Firmicutes', value: 44),
  TaxonAbundance(name: 'Bacteroidota', value: 39),
  TaxonAbundance(name: 'Actinobacteriota', value: 9),
  TaxonAbundance(name: 'Proteobacteria', value: 5),
  TaxonAbundance(name: '기타', value: 3),
];

const _phylumPrevious = <TaxonAbundance>[
  TaxonAbundance(name: 'Firmicutes', value: 51),
  TaxonAbundance(name: 'Bacteroidota', value: 31),
  TaxonAbundance(name: 'Actinobacteriota', value: 8),
  TaxonAbundance(name: 'Proteobacteria', value: 7),
  TaxonAbundance(name: '기타', value: 3),
];

final clinicalDemoGutReports = <GutReport>[
  GutReport(
    reportId: 'gut-demo-20260801',
    userId: clinicalDemoProfile.uid,
    sampledAt: DateTime(2026, 8, 1),
    reportedAt: DateTime(2026, 8, 3),
    policyVersion: 'gut-demo-v1',
    overall: const ScoreSummary(
      score: 86,
      status: 'scored',
      label: '다양성 양호',
    ),
    alpha: _gutAlphaLatest,
    phylum: _phylumLatest,
  ),
  GutReport(
    reportId: 'gut-demo-20260501',
    userId: clinicalDemoProfile.uid,
    sampledAt: DateTime(2026, 5, 1),
    reportedAt: DateTime(2026, 5, 3),
    policyVersion: 'gut-demo-v1',
    overall: const ScoreSummary(
      score: 74,
      status: 'scored',
      label: '관리 필요',
    ),
    alpha: _gutAlphaPrevious,
    phylum: _phylumPrevious,
  ),
];

final clinicalDemoGutExpert = GutExpertReport(
  summary: clinicalDemoGutReports.first,
  pcoa: const [
    PcoaPoint(
        pc1: 0.08, pc2: 0.11, label: '나', group: 'subject', isSubject: true),
    PcoaPoint(
        pc1: -0.25,
        pc2: 0.17,
        label: 'R1',
        group: 'reference',
        isSubject: false),
    PcoaPoint(
        pc1: -0.12,
        pc2: -0.19,
        label: 'R2',
        group: 'reference',
        isSubject: false),
    PcoaPoint(
        pc1: 0.22,
        pc2: 0.29,
        label: 'R3',
        group: 'reference',
        isSubject: false),
    PcoaPoint(
        pc1: 0.31,
        pc2: -0.08,
        label: 'R4',
        group: 'reference',
        isSubject: false),
    PcoaPoint(
        pc1: -0.36,
        pc2: -0.25,
        label: 'R5',
        group: 'reference',
        isSubject: false),
    PcoaPoint(
        pc1: 0.13,
        pc2: -0.31,
        label: 'R6',
        group: 'reference',
        isSubject: false),
    PcoaPoint(
        pc1: -0.04,
        pc2: 0.36,
        label: 'R7',
        group: 'reference',
        isSubject: false),
  ],
  genus: const [
    TaxonAbundance(name: 'Bacteroides', value: 24),
    TaxonAbundance(name: 'Faecalibacterium', value: 14),
    TaxonAbundance(name: 'Bifidobacterium', value: 9),
    TaxonAbundance(name: 'Prevotella', value: 8),
    TaxonAbundance(name: 'Akkermansia', value: 6),
    TaxonAbundance(name: '기타', value: 39),
  ],
  weightedUnifrac: 0.2841,
  unweightedUnifrac: 0.4175,
  metadata: const {
    'sampleId': 'SYN-GUT-20260801',
    'assay': '16S rRNA V3-V4',
    'sequencingPlatform': 'Illumina MiSeq',
    'pipeline': '기관 승인 분석 파이프라인',
    'pipelineVersion': 'demo-1.0',
    'readCount': 82416,
  },
);

BiomarkerResult _marker(
  String code,
  String panel,
  double value,
  String unit,
  double lower,
  double upper, {
  double score = 88,
  String status = 'within',
  String label = '범위 내',
}) {
  return BiomarkerResult(
    code: code,
    panel: panel,
    value: value,
    unit: unit,
    score: score,
    status: status,
    label: label,
    referenceRange: ReferenceRange(lower: lower, upper: upper, unit: unit),
  );
}

List<BiomarkerResult> _bloodMarkers({required bool latest}) => [
      _marker('ALT', 'liver', latest ? 24 : 31, 'U/L', 7, 56),
      _marker('AST', 'liver', latest ? 22 : 29, 'U/L', 10, 40),
      _marker('TBIL', 'liver', latest ? 0.8 : 0.9, 'mg/dL', 0.3, 1.2),
      _marker('DBIL', 'liver', latest ? 0.2 : 0.25, 'mg/dL', 0, 0.3),
      _marker('TP', 'liver', latest ? 7.1 : 6.8, 'g/dL', 6, 8.3),
      _marker('ALB', 'liver', latest ? 4.4 : 4.1, 'g/dL', 3.5, 5),
      _marker('UREA', 'kidney', latest ? 15 : 17, 'mg/dL', 7, 20),
      _marker('CRE', 'kidney', latest ? 0.95 : 1.08, 'mg/dL', 0.6, 1.3),
      _marker('UA', 'kidney', latest ? 5.8 : 6.2, 'mg/dL', 3.4, 7),
      _marker(
        'GLU',
        'metabolic',
        latest ? 103 : 112,
        'mg/dL',
        70,
        99,
        score: latest ? 68 : 58,
        status: 'attention',
        label: '경계',
      ),
      _marker('TG', 'lipid', latest ? 132 : 148, 'mg/dL', 40, 150),
      _marker('CHOL', 'lipid', latest ? 184 : 197, 'mg/dL', 125, 200),
      _marker('HDL-C', 'lipid', latest ? 52 : 46, 'mg/dL', 40, 80),
    ];

Map<String, BloodPanelSummary> _panels({required bool latest}) => {
      'liver': BloodPanelSummary(
        panel: 'liver',
        score: latest ? 90 : 82,
        completeness: 1,
        status: 'scored',
      ),
      'kidney': BloodPanelSummary(
        panel: 'kidney',
        score: latest ? 84 : 76,
        completeness: 1,
        status: 'scored',
      ),
      'metabolic': BloodPanelSummary(
        panel: 'metabolic',
        score: latest ? 68 : 58,
        completeness: 1,
        status: 'attention',
      ),
      'lipid': BloodPanelSummary(
        panel: 'lipid',
        score: latest ? 81 : 71,
        completeness: 1,
        status: 'scored',
      ),
    };

final clinicalDemoBloodReports = <BloodReport>[
  BloodReport(
    reportId: 'blood-demo-20260802',
    userId: clinicalDemoProfile.uid,
    sampledAt: DateTime(2026, 8, 2),
    reportedAt: DateTime(2026, 8, 2),
    policyVersion: 'blood-demo-v1',
    overall: const ScoreSummary(score: 79, status: 'scored', label: '관리 양호'),
    biomarkers: _bloodMarkers(latest: true),
    panels: _panels(latest: true),
    reviewCount: 0,
  ),
  BloodReport(
    reportId: 'blood-demo-20260502',
    userId: clinicalDemoProfile.uid,
    sampledAt: DateTime(2026, 5, 2),
    reportedAt: DateTime(2026, 5, 2),
    policyVersion: 'blood-demo-v1',
    overall: const ScoreSummary(score: 70, status: 'scored', label: '추적 관리'),
    biomarkers: _bloodMarkers(latest: false),
    panels: _panels(latest: false),
    reviewCount: 0,
  ),
];

final clinicalDemoBloodExpert = BloodExpertReport(
  summary: clinicalDemoBloodReports.first,
  normalizedBiomarkers: [
    for (final marker in clinicalDemoBloodReports.first.biomarkers)
      {
        'code': marker.code,
        'sourceValue': switch (marker.code) {
          'CRE' => 84.0,
          'GLU' => 5.72,
          _ => marker.value,
        },
        'sourceUnit': switch (marker.code) {
          'CRE' => 'µmol/L',
          'GLU' => 'mmol/L',
          _ => marker.unit,
        },
        'value': marker.value,
        'unit': marker.unit,
      },
  ],
  analyzer: const {
    'manufacturer': 'D-FET Synthetic Lab',
    'model': 'POCT-DEMO-13',
    'udi': 'UDI-SYNTHETIC-2026',
    'lot': 'LOT-DEMO-0802',
    'expiresAt': '2027-08-01',
  },
);

final clinicalDemoSnapshots = <HealthSnapshot>[
  HealthSnapshot(
    snapshotId: 'snapshot-demo-20260803',
    userId: clinicalDemoProfile.uid,
    asOf: DateTime(2026, 8, 3),
    axes: const {'fitness': 82, 'diet': 74, 'gut': 86, 'blood': 79},
    missingAxes: const [],
    completeness: 1,
    overallScore: 80.3,
    label: '균형 양호',
    policyVersion: 'insight-demo-v1',
    insights: const [
      HealthInsight(
        id: 'gut-diet',
        title: '식단과 장 다양성',
        body: '최근 식이섬유 섭취 기록과 장내미생물 다양성 개선이 함께 관찰되었습니다.',
        action: {
          'title': '식이섬유 루틴 유지',
          'description': '통곡물과 채소를 하루 두 끼 이상 유지해 다음 검사와 비교해 보세요.',
        },
      ),
      HealthInsight(
        id: 'fitness-blood',
        title: '운동과 대사 지표',
        body: '규칙적인 유산소 운동 기간에 혈당과 중성지방 지표가 함께 개선되는 경향이 보입니다.',
        action: {
          'title': '주 3회 유산소 권장',
          'description': '중강도 유산소 운동을 30분씩 기록하고 혈액 추이와 함께 확인하세요.',
        },
      ),
    ],
  ),
  HealthSnapshot(
    snapshotId: 'snapshot-demo-20260503',
    userId: clinicalDemoProfile.uid,
    asOf: DateTime(2026, 5, 3),
    axes: const {'fitness': 73, 'diet': 68, 'gut': 74, 'blood': 70},
    missingAxes: const [],
    completeness: 1,
    overallScore: 71.3,
    label: '관리 시작',
    policyVersion: 'insight-demo-v1',
    insights: const [],
  ),
];
