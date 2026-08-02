DateTime _readDate(Object? value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

double? _nullableDouble(Object? value) => (value as num?)?.toDouble();

class ReferenceRange {
  final double? lower;
  final double? upper;
  final String? unit;

  const ReferenceRange({this.lower, this.upper, this.unit});

  factory ReferenceRange.fromMap(Object? value) {
    final map = _map(value);
    return ReferenceRange(
      lower: _nullableDouble(map['lower']),
      upper: _nullableDouble(map['upper']),
      unit: map['unit'] as String?,
    );
  }
}

class ScoreSummary {
  final double? score;
  final String status;
  final String label;

  const ScoreSummary({
    required this.score,
    required this.status,
    required this.label,
  });

  bool get isScored => score != null && status == 'scored';

  factory ScoreSummary.fromMap(Object? value) {
    final map = _map(value);
    return ScoreSummary(
      score: _nullableDouble(map['score']),
      status: map['status'] as String? ?? 'unscored',
      label: map['label'] as String? ?? '산정 준비 중',
    );
  }
}

class MetricAssessment {
  final double value;
  final double? score;
  final String status;
  final String label;
  final ReferenceRange? referenceRange;

  const MetricAssessment({
    required this.value,
    required this.score,
    required this.status,
    required this.label,
    this.referenceRange,
  });

  factory MetricAssessment.fromMap(Object? value) {
    final map = _map(value);
    return MetricAssessment(
      value: _nullableDouble(map['value']) ?? 0,
      score: _nullableDouble(map['score']),
      status: map['status'] as String? ?? 'unscored',
      label: map['label'] as String? ?? '산정 준비 중',
      referenceRange: map['referenceRange'] == null
          ? null
          : ReferenceRange.fromMap(map['referenceRange']),
    );
  }
}

class TaxonAbundance {
  final String name;
  final double value;

  const TaxonAbundance({required this.name, required this.value});

  factory TaxonAbundance.fromMap(Object? value) {
    final map = _map(value);
    return TaxonAbundance(
      name: map['name'] as String? ?? '',
      value: _nullableDouble(map['value']) ?? 0,
    );
  }
}

class PcoaPoint {
  final double pc1;
  final double pc2;
  final String? label;
  final String? group;
  final bool isSubject;

  const PcoaPoint({
    required this.pc1,
    required this.pc2,
    this.label,
    this.group,
    required this.isSubject,
  });

  factory PcoaPoint.fromMap(Object? value) {
    final map = _map(value);
    return PcoaPoint(
      pc1: _nullableDouble(map['pc1']) ?? 0,
      pc2: _nullableDouble(map['pc2']) ?? 0,
      label: map['label'] as String?,
      group: map['group'] as String?,
      isSubject: map['isSubject'] as bool? ?? false,
    );
  }
}

class GutReport {
  final String reportId;
  final String userId;
  final DateTime sampledAt;
  final DateTime reportedAt;
  final String? policyVersion;
  final ScoreSummary overall;
  final Map<String, MetricAssessment> alpha;
  final List<TaxonAbundance> phylum;

  const GutReport({
    required this.reportId,
    required this.userId,
    required this.sampledAt,
    required this.reportedAt,
    required this.policyVersion,
    required this.overall,
    required this.alpha,
    required this.phylum,
  });

  factory GutReport.fromMap(Map<String, dynamic> map, String id) {
    final alphaMap = _map(map['alpha']);
    final composition = _map(map['composition']);
    return GutReport(
      reportId: map['reportId'] as String? ?? id,
      userId: map['userId'] as String? ?? '',
      sampledAt: _readDate(map['sampledAt']),
      reportedAt: _readDate(map['reportedAt']),
      policyVersion: map['policyVersion'] as String?,
      overall: ScoreSummary.fromMap(map['overall']),
      alpha: alphaMap.map(
        (key, value) => MapEntry(key, MetricAssessment.fromMap(value)),
      ),
      phylum: (composition['phylum'] as List<dynamic>? ?? const [])
          .map(TaxonAbundance.fromMap)
          .toList(growable: false),
    );
  }
}

class GutExpertReport {
  final GutReport summary;
  final List<PcoaPoint> pcoa;
  final List<TaxonAbundance> genus;
  final double? weightedUnifrac;
  final double? unweightedUnifrac;
  final Map<String, dynamic> metadata;

  const GutExpertReport({
    required this.summary,
    required this.pcoa,
    required this.genus,
    required this.weightedUnifrac,
    required this.unweightedUnifrac,
    required this.metadata,
  });

  factory GutExpertReport.fromMap(Map<String, dynamic> map, String id) {
    final normalized = _map(map['normalized']);
    final beta = _map(normalized['beta']);
    final abundance = _map(normalized['abundance']);
    final unifrac = _map(normalized['unifrac']);
    final summaryMap = <String, dynamic>{
      ...map,
      'alpha': _map(map['scored'])['metrics'],
      'composition': {'phylum': abundance['phylum']},
    };
    return GutExpertReport(
      summary: GutReport.fromMap(summaryMap, id),
      pcoa: (beta['pcoa'] as List<dynamic>? ?? const [])
          .map(PcoaPoint.fromMap)
          .toList(growable: false),
      genus: (abundance['genus'] as List<dynamic>? ?? const [])
          .map(TaxonAbundance.fromMap)
          .toList(growable: false),
      weightedUnifrac: _nullableDouble(unifrac['weighted']),
      unweightedUnifrac: _nullableDouble(unifrac['unweighted']),
      metadata: _map(normalized['metadata']),
    );
  }
}

class BiomarkerResult {
  final String code;
  final String panel;
  final double value;
  final String unit;
  final double? score;
  final String status;
  final String label;
  final ReferenceRange? referenceRange;

  const BiomarkerResult({
    required this.code,
    required this.panel,
    required this.value,
    required this.unit,
    this.score,
    required this.status,
    required this.label,
    this.referenceRange,
  });

  factory BiomarkerResult.fromMap(Object? value) {
    final map = _map(value);
    return BiomarkerResult(
      code: map['code'] as String? ?? '',
      panel: map['panel'] as String? ?? '',
      value: _nullableDouble(map['value']) ?? 0,
      unit: map['unit'] as String? ?? '',
      score: _nullableDouble(map['score']),
      status: map['status'] as String? ?? 'unscored',
      label: map['label'] as String? ?? '산정 준비 중',
      referenceRange: map['referenceRange'] == null
          ? null
          : ReferenceRange.fromMap(map['referenceRange']),
    );
  }
}

class BloodPanelSummary {
  final String panel;
  final double? score;
  final double completeness;
  final String status;

  const BloodPanelSummary({
    required this.panel,
    this.score,
    required this.completeness,
    required this.status,
  });

  factory BloodPanelSummary.fromMap(String panel, Object? value) {
    final map = _map(value);
    return BloodPanelSummary(
      panel: panel,
      score: _nullableDouble(map['score']),
      completeness: _nullableDouble(map['completeness']) ?? 0,
      status: map['status'] as String? ?? 'unscored',
    );
  }
}

class BloodReport {
  final String reportId;
  final String userId;
  final DateTime sampledAt;
  final DateTime reportedAt;
  final String? policyVersion;
  final ScoreSummary overall;
  final List<BiomarkerResult> biomarkers;
  final Map<String, BloodPanelSummary> panels;
  final int reviewCount;

  const BloodReport({
    required this.reportId,
    required this.userId,
    required this.sampledAt,
    required this.reportedAt,
    required this.policyVersion,
    required this.overall,
    required this.biomarkers,
    required this.panels,
    required this.reviewCount,
  });

  factory BloodReport.fromMap(Map<String, dynamic> map, String id) {
    final panelMap = _map(map['panels']);
    final summary = _map(map['summary']);
    return BloodReport(
      reportId: map['reportId'] as String? ?? id,
      userId: map['userId'] as String? ?? '',
      sampledAt: _readDate(map['sampledAt']),
      reportedAt: _readDate(map['reportedAt']),
      policyVersion: map['policyVersion'] as String?,
      overall: ScoreSummary.fromMap(map['overall']),
      biomarkers: (map['biomarkers'] as List<dynamic>? ?? const [])
          .map(BiomarkerResult.fromMap)
          .toList(growable: false),
      panels: panelMap.map(
        (key, value) => MapEntry(key, BloodPanelSummary.fromMap(key, value)),
      ),
      reviewCount: summary['reviewCount'] as int? ?? 0,
    );
  }
}

class BloodExpertReport {
  final BloodReport summary;
  final List<Map<String, dynamic>> normalizedBiomarkers;
  final Map<String, dynamic>? analyzer;

  const BloodExpertReport({
    required this.summary,
    required this.normalizedBiomarkers,
    this.analyzer,
  });

  factory BloodExpertReport.fromMap(Map<String, dynamic> map, String id) {
    final normalized = _map(map['normalized']);
    final scored = _map(map['scored']);
    final summaryMap = <String, dynamic>{
      ...map,
      'biomarkers': scored['biomarkers'],
      'panels': scored['panels'],
      'summary': {
        'reviewCount': (scored['biomarkers'] as List<dynamic>? ?? const [])
            .where((value) => _map(value)['status'] == 'review')
            .length,
      },
    };
    return BloodExpertReport(
      summary: BloodReport.fromMap(summaryMap, id),
      normalizedBiomarkers:
          (normalized['biomarkers'] as List<dynamic>? ?? const [])
              .map(_map)
              .toList(growable: false),
      analyzer:
          normalized['analyzer'] == null ? null : _map(normalized['analyzer']),
    );
  }
}

class HealthInsight {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? action;

  const HealthInsight({
    required this.id,
    required this.title,
    required this.body,
    this.action,
  });

  factory HealthInsight.fromMap(Object? value) {
    final map = _map(value);
    return HealthInsight(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      action: map['action'] == null ? null : _map(map['action']),
    );
  }
}

class HealthSnapshot {
  final String snapshotId;
  final String userId;
  final DateTime asOf;
  final Map<String, double?> axes;
  final List<String> missingAxes;
  final double completeness;
  final double? overallScore;
  final String label;
  final String? policyVersion;
  final List<HealthInsight> insights;

  const HealthSnapshot({
    required this.snapshotId,
    required this.userId,
    required this.asOf,
    required this.axes,
    required this.missingAxes,
    required this.completeness,
    this.overallScore,
    required this.label,
    this.policyVersion,
    required this.insights,
  });

  factory HealthSnapshot.fromMap(Map<String, dynamic> map, String id) {
    final axesMap = _map(map['axes']);
    return HealthSnapshot(
      snapshotId: map['snapshotId'] as String? ?? id,
      userId: map['userId'] as String? ?? '',
      asOf: _readDate(map['asOf']),
      axes: axesMap.map((key, value) => MapEntry(key, _nullableDouble(value))),
      missingAxes: (map['missingAxes'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      completeness: _nullableDouble(map['completeness']) ?? 0,
      overallScore: _nullableDouble(map['overallScore']),
      label: map['label'] as String? ?? '산정 준비 중',
      policyVersion: map['policyVersion'] as String?,
      insights: (map['insights'] as List<dynamic>? ?? const [])
          .map(HealthInsight.fromMap)
          .toList(growable: false),
    );
  }
}
