// SOAP schema v2 model (PRD §9.3, docs/v1/05_DATA_MODEL_AND_RULES.md §5).
//
// DF-007: used for cross-client fixture tests, legacy compatibility and migration checks.
// Member screens do not read soap notes (AC-VIZ-06.1); they read memberSummaries from P2.
// Encoding and decoding live in soap_note_v2_codec.dart.
//
// Lossless rules shared by every class here:
// - A key the model does not know, or a known key whose value has the wrong type or an
//   unknown enum value, is kept in `extra` under the same key and written back as is.
//   The typed field is then null, which callers show as 'uninterpretable' (해석 불가).
// - Absent and present-null are different (V1-10 §6.1). Fields that may hold null use
//   [Present]: a Dart null field means the key is absent, `Present(null)` means the key
//   is present with null.
// - An `objective.metrics` row is either [ParsedSoapMetric] or [UnparsedSoapMetric]
//   (F-SOAP-06.2). A row is never dropped: an element that is not a map is an
//   [UnparsedSoapMetric] too, so `metrics.length` equals the stored length.
// - An `objective.snapshots` element that is not a map is kept in place as
//   [ObjectiveSnapshot.element].

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart' show immutable;

import '../contracts/generated/metric_catalog.g.dart';
import '../contracts/generated/vocab.g.dart';

export '../contracts/generated/metric_catalog.g.dart' show MetricCode;
export '../contracts/generated/vocab.g.dart'
    show
        ActiveOrPassive,
        ChangeStatus,
        Joint,
        MdcSource,
        MetricUnit,
        Motion,
        MuscleGroup,
        ReasonCode,
        RegionCode,
        Side,
        SoapStatus,
        SourceGrade;

/// A key that is present in the document. [value] may be null (present-null).
///
/// A field of type `Present<T>?` that is itself null means the key is absent.
@immutable
final class Present<T> {
  const Present(this.value);

  final T? value;

  @override
  bool operator ==(Object other) =>
      other is Present && _deepEquals(value, other.value);

  @override
  int get hashCode => Object.hash(Present, _deepHash(value));

  @override
  String toString() => 'Present($value)';
}

/// A Firestore timestamp field: a stored instant, or the server-time placeholder of a
/// write payload (fixture tag `$serverTimestamp`).
@immutable
sealed class SoapTimestamp {
  const SoapTimestamp();

  /// A stored instant.
  const factory SoapTimestamp.instant(Timestamp timestamp) = SoapInstant;

  /// `FieldValue.serverTimestamp()` in a write payload.
  const factory SoapTimestamp.server() = SoapServerTimestamp;

  /// Convenience for hand-built models and tests.
  factory SoapTimestamp.at(DateTime time) =>
      SoapInstant(Timestamp.fromDate(time));
}

final class SoapInstant extends SoapTimestamp {
  const SoapInstant(this.timestamp);

  final Timestamp timestamp;

  DateTime toDateTime() => timestamp.toDate().toUtc();

  @override
  bool operator ==(Object other) =>
      other is SoapInstant && other.timestamp == timestamp;

  @override
  int get hashCode => timestamp.hashCode;

  @override
  String toString() => 'SoapInstant(${toDateTime().toIso8601String()})';
}

final class SoapServerTimestamp extends SoapTimestamp {
  const SoapServerTimestamp();

  @override
  bool operator ==(Object other) => other is SoapServerTimestamp;

  @override
  int get hashCode => (SoapServerTimestamp).hashCode;

  @override
  String toString() => 'SoapServerTimestamp()';
}

/// `soap_notes/{noteId}` schema v2 (V1-05 §5.1).
@immutable
final class SoapNoteV2 with _ValueEquality {
  const SoapNoteV2({
    this.schemaVersion = 2,
    this.trainerId,
    this.authorUid,
    this.memberUid,
    this.memberId,
    this.pendingMemberId,
    this.sessionDate,
    this.status,
    this.quickNote,
    this.inkPath,
    this.inkRevision,
    this.subjective,
    this.objective,
    this.exerciseAssessment,
    this.plan,
    this.memberNote,
    this.legalNature,
    this.isSharedWithMember,
    this.finalizedAt,
    this.createdAt,
    this.updatedAt,
    this.memberSummaryId,
    this.migratedFrom,
    this.legacy,
    this.extra = const {},
  });

  final int schemaVersion;
  final Present<String>? trainerId;
  final String? authorUid;
  final Present<String>? memberUid;

  /// Legacy mirror of [memberUid] during the compatibility period (P0~P3).
  final String? memberId;
  final Present<String>? pendingMemberId;
  final SoapTimestamp? sessionDate;

  /// Null when the key is absent or the value is unknown (the raw value is in [extra]).
  final SoapStatus? status;
  final String? quickNote;
  final Present<String>? inkPath;
  final int? inkRevision;
  final SoapSubjective? subjective;
  final SoapObjective? objective;
  final ExerciseAssessment? exerciseAssessment;
  final SoapPlan? plan;
  final String? memberNote;
  final String? legalNature;

  /// Legacy flag. v2 writers write false only (D9).
  final bool? isSharedWithMember;
  final SoapTimestamp? finalizedAt;
  final SoapTimestamp? createdAt;
  final SoapTimestamp? updatedAt;

  /// Server-only (P2 back reference). Read only; never written to Firestore by a client.
  final Present<String>? memberSummaryId;

  /// Server-only migration marker `{runId, schemaVersion}`. Read only.
  final Map<String, Object?>? migratedFrom;

  /// Server-only legacy originals `{metricsRaw, diagnosisRaw?, ...}`. Read only and never
  /// shown on member surfaces (MIG-04).
  final Map<String, Object?>? legacy;

  /// Unknown top-level keys and known keys whose value could not be read.
  final Map<String, Object?> extra;

  /// All `objective.metrics` rows, parsed or not.
  List<SoapMetricV2> get metrics => objective?.metrics ?? const [];

  /// Rows shown as 'uninterpretable' (해석 불가).
  int get uninterpretableMetricCount =>
      metrics.where((m) => !m.isInterpretable).length;

  @override
  List<Object?> get _props => [
        schemaVersion,
        trainerId,
        authorUid,
        memberUid,
        memberId,
        pendingMemberId,
        sessionDate,
        status,
        quickNote,
        inkPath,
        inkRevision,
        subjective,
        objective,
        exerciseAssessment,
        plan,
        memberNote,
        legalNature,
        isSharedWithMember,
        finalizedAt,
        createdAt,
        updatedAt,
        memberSummaryId,
        migratedFrom,
        legacy,
        extra,
      ];
}

/// `subjective` (V1-05 §5.2).
@immutable
final class SoapSubjective with _ValueEquality {
  const SoapSubjective({
    this.chiefComplaint,
    this.painNrs,
    this.painRegions,
    this.extra = const {},
  });

  final String? chiefComplaint;

  /// 0~10 integer. `Present(null)` means 'not entered', which is different from 0
  /// (AC-SOAP-01.7).
  final Present<int>? painNrs;

  /// Wire values as stored. Unknown codes are kept (TC-X-XC-10: reading keeps the raw value).
  final List<String>? painRegions;
  final Map<String, Object?> extra;

  /// [painRegions] parsed with the contract vocab. Unknown codes are null.
  List<RegionCode?> get painRegionCodes =>
      [for (final r in painRegions ?? const <String>[]) RegionCode.fromWire(r)];

  @override
  List<Object?> get _props => [chiefComplaint, painNrs, painRegions, extra];
}

/// `objective` (V1-05 §5.2).
@immutable
final class SoapObjective with _ValueEquality {
  const SoapObjective({
    this.metrics,
    this.refs,
    this.snapshots,
    this.extra = const {},
  });

  final List<SoapMetricV2>? metrics;
  final ObjectiveRefs? refs;
  final List<ObjectiveSnapshot>? snapshots;
  final Map<String, Object?> extra;

  @override
  List<Object?> get _props => [metrics, refs, snapshots, extra];
}

/// One `objective.metrics[]` row (V1-05 §5.2).
///
/// [ParsedSoapMetric] when the metricCode is in the catalog and every enum field is a known
/// wire value; otherwise [UnparsedSoapMetric] with the original map (F-SOAP-06.2).
@immutable
sealed class SoapMetricV2 {
  const SoapMetricV2();

  const factory SoapMetricV2.parsed({
    required MetricCode metricCode,
    required num value,
    required MetricUnit unit,
    required Side side,
    required SourceGrade sourceGrade,
    Joint? joint,
    Motion? motion,
    ActiveOrPassive? activeOrPassive,
    MuscleGroup? muscleGroup,
    String? note,
    Map<String, Object?> extra,
  }) = ParsedSoapMetric;

  const factory SoapMetricV2.unparsed(Object? raw) = UnparsedSoapMetric;

  /// False for rows shown as 'uninterpretable' (해석 불가).
  bool get isInterpretable;
}

final class ParsedSoapMetric extends SoapMetricV2 with _ValueEquality {
  const ParsedSoapMetric({
    required this.metricCode,
    required this.value,
    required this.unit,
    required this.side,
    required this.sourceGrade,
    this.joint,
    this.motion,
    this.activeOrPassive,
    this.muscleGroup,
    this.note,
    this.extra = const {},
  });

  final MetricCode metricCode;

  /// `mmtGrade` values are integers (fixture tag `$int`); other values are doubles.
  final num value;
  final MetricUnit unit;
  final Side side;
  final SourceGrade sourceGrade;
  final Joint? joint;
  final Motion? motion;
  final ActiveOrPassive? activeOrPassive;
  final MuscleGroup? muscleGroup;
  final String? note;

  /// Row keys this version does not know. Kept and written back.
  final Map<String, Object?> extra;

  @override
  bool get isInterpretable => true;

  MetricCatalogEntry get catalogEntry => MetricCatalog.entry(metricCode);

  /// Whether the row meets V1-05 §5.2 (catalog unit, sourceGrade, side rule and the
  /// romDeg/mmtGrade condition fields). Incomplete rows are shown as '미완성' and are
  /// not saved on finalize (F-SOAP-02.6). The codec keeps them either way.
  bool get isComplete {
    final entry = catalogEntry;
    if (entry.storage.field != 'objective.metrics') return false;
    if (unit != entry.unit) return false;
    if (!entry.allowedSourceGrades.contains(sourceGrade)) return false;
    switch (entry.sideRule) {
      case SideRule.leftRightBilateral:
        if (side == Side.none) return false;
      case SideRule.leftRight:
        if (side != Side.left && side != Side.right) return false;
      case SideRule.none:
        if (side != Side.none) return false;
      case SideRule.magnitudeWithLowerSide ||
            SideRule.magnitudeWithHigherSide ||
            SideRule.undefinedV2:
        break;
    }
    switch (metricCode) {
      case MetricCode.romDeg:
        return joint != null && motion != null && activeOrPassive != null;
      case MetricCode.mmtGrade:
        return muscleGroup != null && value is int && value >= 0 && value <= 5;
      default:
        return true;
    }
  }

  @override
  List<Object?> get _props => [
        metricCode,
        value,
        unit,
        side,
        sourceGrade,
        joint,
        motion,
        activeOrPassive,
        muscleGroup,
        note,
        extra,
      ];
}

final class UnparsedSoapMetric extends SoapMetricV2 with _ValueEquality {
  const UnparsedSoapMetric(this.raw);

  /// The original row, written back unchanged. Normally a map; any other stored element
  /// (a string, a number, null, a list) is kept as it is so the row count never shrinks.
  final Object? raw;

  /// Whether the stored row is a map.
  bool get isMapRow => raw is Map;

  /// The raw `metricCode`, if the row is a map and the code is a string.
  String? get metricCodeWire {
    final row = raw;
    final code = row is Map ? row['metricCode'] : null;
    return code is String ? code : null;
  }

  @override
  bool get isInterpretable => false;

  @override
  List<Object?> get _props => [raw];
}

/// `objective.refs` (V1-05 §5.2).
@immutable
final class ObjectiveRefs with _ValueEquality {
  const ObjectiveRefs({
    this.postureAssessmentIds,
    this.bodyCompositionRecordIds,
    this.circumferenceMeasurementIds,
    this.bodyScanIds,
    this.extra = const {},
  });

  final List<String>? postureAssessmentIds;
  final List<String>? bodyCompositionRecordIds;
  final List<String>? circumferenceMeasurementIds;
  final List<String>? bodyScanIds;
  final Map<String, Object?> extra;

  @override
  List<Object?> get _props => [
        postureAssessmentIds,
        bodyCompositionRecordIds,
        circumferenceMeasurementIds,
        bodyScanIds,
        extra,
      ];
}

/// `objective.snapshots[]`: immutable copy of a referenced record value (PRD §7.8).
@immutable
final class ObjectiveSnapshot with _ValueEquality {
  const ObjectiveSnapshot({
    this.element,
    this.refId,
    this.metricCode,
    this.value,
    this.unit,
    this.side,
    this.sourceGrade,
    this.changeStatus,
    this.reasonCode,
    this.policyVersion,
    this.mdcSource,
    this.measuredAt,
    this.extra = const {},
  });

  final String? refId;
  final MetricCode? metricCode;
  final num? value;
  final MetricUnit? unit;
  final Side? side;
  final SourceGrade? sourceGrade;

  /// Always `pendingPolicy` before P3 (ADR-009).
  final ChangeStatus? changeStatus;
  final Present<ReasonCode>? reasonCode;
  final Present<String>? policyVersion;
  final Present<MdcSource>? mdcSource;
  final SoapTimestamp? measuredAt;
  final Map<String, Object?> extra;

  /// Set only when the stored element is not a map: the element as stored (possibly
  /// `Present(null)`), written back unchanged. Every other field is then null.
  final Present<Object>? element;

  /// Whether the stored element was a map that could be read field by field.
  bool get isReadable => element == null;

  @override
  List<Object?> get _props => [
        element,
        refId,
        metricCode,
        value,
        unit,
        side,
        sourceGrade,
        changeStatus,
        reasonCode,
        policyVersion,
        mdcSource,
        measuredAt,
        extra,
      ];
}

/// `exerciseAssessment` (V1-05 §5.1).
@immutable
final class ExerciseAssessment with _ValueEquality {
  const ExerciseAssessment({
    this.summary,
    this.observations,
    this.extra = const {},
  });

  final String? summary;
  final List<String>? observations;
  final Map<String, Object?> extra;

  @override
  List<Object?> get _props => [summary, observations, extra];
}

/// `plan` (V1-05 §5.1).
@immutable
final class SoapPlan with _ValueEquality {
  const SoapPlan({this.nextSession, this.homeExercise, this.extra = const {}});

  final String? nextSession;
  final String? homeExercise;
  final Map<String, Object?> extra;

  @override
  List<Object?> get _props => [nextSession, homeExercise, extra];
}

// -------------------------------------------------------------------------------------------
// Value equality. Maps compare without key order; `null` and a missing key are different.
// -------------------------------------------------------------------------------------------

mixin _ValueEquality {
  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is _ValueEquality &&
          _deepEquals(_props, other._props));

  @override
  int get hashCode => _deepHash(_props);

  @override
  String toString() => '$runtimeType$_props';
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? v) {
  if (v is Map) {
    var h = 0;
    for (final e in v.entries) {
      h ^= Object.hash(e.key, _deepHash(e.value));
    }
    return Object.hash(Map, h, v.length);
  }
  if (v is List) return Object.hashAll(v.map(_deepHash));
  return v.hashCode;
}
