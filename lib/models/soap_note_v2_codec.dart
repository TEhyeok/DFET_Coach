// SoapNoteV2 <-> map codec (DF-007, PRD §9.3, docs/v1/05_DATA_MODEL_AND_RULES.md §5).
//
// Decoding reads Firestore types (Timestamp, int, double, Blob; FieldValue.serverTimestamp()
// in write payloads). Test fixtures are turned into those types by
// test/contracts/fixture_io.dart first, so there is one decoding path.
//
// Encoding has two targets:
// - [CodecTarget.firestore]: Firestore types, limited to the client write whitelist
//   (V1-05 §7.3 soapCreateKeys + finalizedAt, nested hasOnly maps). Server-only fields
//   (memberSummaryId, migratedFrom, legacy), unknown top-level keys and unknown nested keys
//   are left out. A known key whose value could not be read is written back unchanged, and
//   list elements (metrics rows, snapshots) are never dropped.
// - [CodecTarget.fixture]: the cross-client fixture notation (P0 DF-005 fixture contract,
//   rule 2: `$ts`, `$serverTimestamp`, `$int`, `$bytes` for legacy bytes). Everything that
//   was read is written back, so decode -> encode is identical (AC-DF-007.1).

import 'dart:convert' show base64;

import 'package:cloud_firestore/cloud_firestore.dart'
    show Blob, FieldValue, Timestamp;

import 'soap_note_v2.dart';

/// Where an encoded map goes.
enum CodecTarget {
  /// A Firestore write payload.
  firestore,

  /// The cross-client fixture notation (contracts/fixtures/**).
  fixture,
}

/// Decodes and encodes `soap_notes` schema v2 documents.
abstract final class SoapNoteV2Codec {
  /// Top-level keys a client may write (V1-05 §7.3 `soapCreateKeys()` + `finalizedAt`).
  static const Set<String> clientWritableKeys = {
    'schemaVersion',
    'trainerId',
    'authorUid',
    'memberUid',
    'pendingMemberId',
    'memberId',
    'isSharedWithMember',
    'sessionDate',
    'status',
    'quickNote',
    'inkPath',
    'inkRevision',
    'subjective',
    'objective',
    'exerciseAssessment',
    'plan',
    'memberNote',
    'legalNature',
    'finalizedAt',
    'createdAt',
    'updatedAt',
  };

  /// Fields only the server writes. Read, never written by [CodecTarget.firestore].
  static const Set<String> serverOnlyKeys = {
    'memberSummaryId',
    'migratedFrom',
    'legacy',
  };

  /// Whether [map] is a schema v2 document. Documents without `schemaVersion` are v1 and
  /// are read with `LegacySoapView` (V1-05 §5.6).
  static bool isV2(Map<String, dynamic> map) {
    final version = map['schemaVersion'];
    return version is num && version == 2;
  }

  /// Decodes a v2 document. Throws [FormatException] when [map] is not schema v2.
  static SoapNoteV2 fromMap(Map<String, dynamic> map) {
    if (!isV2(map)) {
      throw FormatException(
        'Not a soap_notes schema v2 document (schemaVersion ${map['schemaVersion']}). '
        'Read v1 documents with LegacySoapView.',
      );
    }
    final r = _MapReader(map);
    r.integer('schemaVersion');
    return SoapNoteV2(
      trainerId: r.nullableString('trainerId'),
      authorUid: r.string('authorUid'),
      memberUid: r.nullableString('memberUid'),
      memberId: r.string('memberId'),
      pendingMemberId: r.nullableString('pendingMemberId'),
      sessionDate: r.timestamp('sessionDate'),
      status: r.enumValue('status', SoapStatus.fromWire),
      quickNote: r.string('quickNote'),
      inkPath: r.nullableString('inkPath'),
      inkRevision: r.integer('inkRevision'),
      subjective: r.object('subjective', _subjective),
      objective: r.object('objective', _objective),
      exerciseAssessment: r.object('exerciseAssessment', _exerciseAssessment),
      plan: r.object('plan', _plan),
      memberNote: r.string('memberNote'),
      legalNature: r.string('legalNature'),
      isSharedWithMember: r.boolean('isSharedWithMember'),
      finalizedAt: r.timestamp('finalizedAt'),
      createdAt: r.timestamp('createdAt'),
      updatedAt: r.timestamp('updatedAt'),
      memberSummaryId: r.nullableString('memberSummaryId'),
      migratedFrom: r.rawMap('migratedFrom'),
      legacy: r.rawMap('legacy'),
      extra: r.finish(),
    );
  }

  /// Encodes [note] for [target].
  ///
  /// The [CodecTarget.firestore] output is a create payload, or an `update()` /
  /// `set(..., SetOptions(merge: true))` payload. It is not a full-document replace: it
  /// leaves out server-only and unknown top-level keys, so `set()` without merge on a stored
  /// document that has `memberSummaryId`, `migratedFrom` or `legacy` would delete them. Those
  /// keys then appear in `affectedKeys()` and the rules reject the write (V1-05 §7.3), so
  /// the mistake fails safely, but do not rely on it.
  static Map<String, Object?> toMap(
    SoapNoteV2 note, {
    CodecTarget target = CodecTarget.firestore,
  }) {
    final w = _Writer(target);
    final out = <String, Object?>{
      'schemaVersion': note.schemaVersion,
      if (note.trainerId != null) 'trainerId': note.trainerId!.value,
      if (note.authorUid != null) 'authorUid': note.authorUid,
      if (note.memberUid != null) 'memberUid': note.memberUid!.value,
      if (note.memberId != null) 'memberId': note.memberId,
      if (note.pendingMemberId != null)
        'pendingMemberId': note.pendingMemberId!.value,
      if (note.sessionDate != null) 'sessionDate': w.ts(note.sessionDate!),
      if (note.status != null) 'status': note.status!.wire,
      if (note.quickNote != null) 'quickNote': note.quickNote,
      if (note.inkPath != null) 'inkPath': note.inkPath!.value,
      if (note.inkRevision != null) 'inkRevision': w.integer(note.inkRevision!),
      if (note.subjective != null)
        'subjective': _encodeSubjective(note.subjective!, w),
      if (note.objective != null)
        'objective': _encodeObjective(note.objective!, w),
      if (note.exerciseAssessment != null)
        'exerciseAssessment':
            _encodeExerciseAssessment(note.exerciseAssessment!, w),
      if (note.plan != null) 'plan': _encodePlan(note.plan!, w),
      if (note.memberNote != null) 'memberNote': note.memberNote,
      if (note.legalNature != null) 'legalNature': note.legalNature,
      if (note.isSharedWithMember != null)
        'isSharedWithMember': note.isSharedWithMember,
      if (note.finalizedAt != null) 'finalizedAt': w.ts(note.finalizedAt!),
      if (note.createdAt != null) 'createdAt': w.ts(note.createdAt!),
      if (note.updatedAt != null) 'updatedAt': w.ts(note.updatedAt!),
      if (note.memberSummaryId != null)
        'memberSummaryId': note.memberSummaryId!.value,
      if (note.migratedFrom != null) 'migratedFrom': w.raw(note.migratedFrom),
      if (note.legacy != null) 'legacy': w.raw(note.legacy),
    };
    w.addExtra(out, note.extra);
    if (target == CodecTarget.firestore) {
      out.removeWhere((key, _) => !clientWritableKeys.contains(key));
    }
    return out;
  }

  // ---------------------------------------------------------------------------------------
  // Nested maps
  // ---------------------------------------------------------------------------------------

  static SoapSubjective _subjective(_MapReader r) => SoapSubjective(
        chiefComplaint: r.string('chiefComplaint'),
        painNrs: r.nullableInteger('painNrs'),
        painRegions: r.stringList('painRegions'),
        extra: r.finish(),
      );

  static Map<String, Object?> _encodeSubjective(SoapSubjective s, _Writer w) {
    final out = <String, Object?>{
      if (s.chiefComplaint != null) 'chiefComplaint': s.chiefComplaint,
      if (s.painNrs != null)
        'painNrs':
            s.painNrs!.value == null ? null : w.integer(s.painNrs!.value!),
      if (s.painRegions != null) 'painRegions': [...s.painRegions!],
    };
    w.addNestedExtra(out, s.extra, _subjectiveKeys);
    return out;
  }

  // Nested key allowlists: the rules' `keys().hasOnly(...)` lists (V1-05 §7.3).
  static const Set<String> _subjectiveKeys = {
    'chiefComplaint',
    'painNrs',
    'painRegions',
  };
  static const Set<String> _objectiveKeys = {'metrics', 'refs', 'snapshots'};
  static const Set<String> _refsKeys = {
    'postureAssessmentIds',
    'bodyCompositionRecordIds',
    'circumferenceMeasurementIds',
    'bodyScanIds',
  };
  static const Set<String> _exerciseAssessmentKeys = {
    'summary',
    'observations'
  };
  static const Set<String> _planKeys = {'nextSession', 'homeExercise'};

  static SoapObjective _objective(_MapReader r) => SoapObjective(
        metrics: r.list('metrics', _metric),
        refs: r.object('refs', _refs),
        snapshots: r.list('snapshots', _snapshot),
        extra: r.finish(),
      );

  static Map<String, Object?> _encodeObjective(SoapObjective o, _Writer w) {
    final out = <String, Object?>{
      if (o.metrics != null)
        'metrics': [for (final m in o.metrics!) _encodeMetric(m, w)],
      if (o.refs != null) 'refs': _encodeRefs(o.refs!, w),
      if (o.snapshots != null)
        'snapshots': [for (final s in o.snapshots!) _encodeSnapshot(s, w)],
    };
    w.addNestedExtra(out, o.extra, _objectiveKeys);
    return out;
  }

  static const Set<String> _metricKeys = {
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
  };

  /// A row is parsed only when every known key reads cleanly; otherwise the whole row is
  /// kept as [UnparsedSoapMetric] (F-SOAP-06.2). An element that is not a map is kept as
  /// an [UnparsedSoapMetric] as well, so no row is ever dropped.
  static SoapMetricV2 _metric(Object? element) {
    if (element is! Map) return SoapMetricV2.unparsed(_copyValue(element));
    final raw = _copyMap(element);
    final metricCode = _wireEnum(raw['metricCode'], MetricCode.fromWire);
    final unit = _wireEnum(raw['unit'], MetricUnit.fromWire);
    final side = _wireEnum(raw['side'], Side.fromWire);
    final sourceGrade = _wireEnum(raw['sourceGrade'], SourceGrade.fromWire);
    final value = _metricValue(metricCode, raw['value']);
    final ok = metricCode != null &&
        unit != null &&
        side != null &&
        sourceGrade != null &&
        value != null &&
        _optionalEnumOk(raw, 'joint', Joint.fromWire) &&
        _optionalEnumOk(raw, 'motion', Motion.fromWire) &&
        _optionalEnumOk(raw, 'activeOrPassive', ActiveOrPassive.fromWire) &&
        _optionalEnumOk(raw, 'muscleGroup', MuscleGroup.fromWire) &&
        (!raw.containsKey('note') || raw['note'] is String);
    if (!ok) return SoapMetricV2.unparsed(raw);
    return SoapMetricV2.parsed(
      metricCode: metricCode,
      value: value,
      unit: unit,
      side: side,
      sourceGrade: sourceGrade,
      joint: _wireEnum(raw['joint'], Joint.fromWire),
      motion: _wireEnum(raw['motion'], Motion.fromWire),
      activeOrPassive:
          _wireEnum(raw['activeOrPassive'], ActiveOrPassive.fromWire),
      muscleGroup: _wireEnum(raw['muscleGroup'], MuscleGroup.fromWire),
      note: raw['note'] as String?,
      extra: Map.unmodifiable({
        for (final e in raw.entries)
          if (!_metricKeys.contains(e.key)) e.key: e.value,
      }),
    );
  }

  /// Integer metrics (fixture rule 2 `$int` list: the `mmtGrade` value). A non-integral
  /// value there cannot be written back as an integer, so the row stays unparsed.
  static num? _metricValue(MetricCode? code, Object? value) {
    if (value is! num || !value.isFinite) return null;
    if (_isIntegerMetric(code)) return _asInt(value);
    return value.toDouble();
  }

  static bool _isIntegerMetric(MetricCode? code) => code == MetricCode.mmtGrade;

  static bool _optionalEnumOk<E>(
    Map<String, Object?> raw,
    String key,
    E? Function(String?) fromWire,
  ) =>
      !raw.containsKey(key) || _wireEnum(raw[key], fromWire) != null;

  static Object? _encodeMetric(SoapMetricV2 metric, _Writer w) {
    switch (metric) {
      case UnparsedSoapMetric(:final raw):
        return w.raw(raw);
      case final ParsedSoapMetric metric:
        final out = <String, Object?>{
          'metricCode': metric.metricCode.wire,
          'value': _isIntegerMetric(metric.metricCode)
              ? w.integer(metric.value.toInt())
              : w.number(metric.value),
          'unit': metric.unit.wire,
          'side': metric.side.wire,
          'sourceGrade': metric.sourceGrade.wire,
          if (metric.joint != null) 'joint': metric.joint!.wire,
          if (metric.motion != null) 'motion': metric.motion!.wire,
          if (metric.activeOrPassive != null)
            'activeOrPassive': metric.activeOrPassive!.wire,
          if (metric.muscleGroup != null)
            'muscleGroup': metric.muscleGroup!.wire,
          if (metric.note != null) 'note': metric.note,
        };
        // Array elements are not checked by the rules, so row extras are kept for both
        // targets (V1-05 §5.2).
        w.addExtra(out, metric.extra);
        return out;
    }
  }

  static ObjectiveRefs _refs(_MapReader r) => ObjectiveRefs(
        postureAssessmentIds: r.stringList('postureAssessmentIds'),
        bodyCompositionRecordIds: r.stringList('bodyCompositionRecordIds'),
        circumferenceMeasurementIds:
            r.stringList('circumferenceMeasurementIds'),
        bodyScanIds: r.stringList('bodyScanIds'),
        extra: r.finish(),
      );

  static Map<String, Object?> _encodeRefs(ObjectiveRefs refs, _Writer w) {
    final out = <String, Object?>{
      if (refs.postureAssessmentIds != null)
        'postureAssessmentIds': [...refs.postureAssessmentIds!],
      if (refs.bodyCompositionRecordIds != null)
        'bodyCompositionRecordIds': [...refs.bodyCompositionRecordIds!],
      if (refs.circumferenceMeasurementIds != null)
        'circumferenceMeasurementIds': [...refs.circumferenceMeasurementIds!],
      if (refs.bodyScanIds != null) 'bodyScanIds': [...refs.bodyScanIds!],
    };
    w.addNestedExtra(out, refs.extra, _refsKeys);
    return out;
  }

  /// A snapshot element that is not a map is kept in place as [ObjectiveSnapshot.element].
  static ObjectiveSnapshot _snapshot(Object? element) {
    if (element is! Map) {
      return ObjectiveSnapshot(element: Present(_copyValue(element)));
    }
    final r = _MapReader(element);
    final metricCode = r.enumValue('metricCode', MetricCode.fromWire);
    return ObjectiveSnapshot(
      refId: r.string('refId'),
      metricCode: metricCode,
      value: r.number('value',
          integer: metricCode == null ? null : _isIntegerMetric(metricCode)),
      unit: r.enumValue('unit', MetricUnit.fromWire),
      side: r.enumValue('side', Side.fromWire),
      sourceGrade: r.enumValue('sourceGrade', SourceGrade.fromWire),
      changeStatus: r.enumValue('changeStatus', ChangeStatus.fromWire),
      reasonCode: r.nullableEnum('reasonCode', ReasonCode.fromWire),
      policyVersion: r.nullableString('policyVersion'),
      mdcSource: r.nullableEnum('mdcSource', MdcSource.fromWire),
      measuredAt: r.timestamp('measuredAt'),
      extra: r.finish(),
    );
  }

  static Object? _encodeSnapshot(ObjectiveSnapshot s, _Writer w) {
    if (s.element case final element?) return w.raw(element.value);
    final out = <String, Object?>{
      if (s.refId != null) 'refId': s.refId,
      if (s.metricCode != null) 'metricCode': s.metricCode!.wire,
      if (s.value != null)
        'value': s.metricCode == null
            ? w.raw(s.value)
            : _isIntegerMetric(s.metricCode)
                ? w.integer(s.value!.toInt())
                : w.number(s.value!),
      if (s.unit != null) 'unit': s.unit!.wire,
      if (s.side != null) 'side': s.side!.wire,
      if (s.sourceGrade != null) 'sourceGrade': s.sourceGrade!.wire,
      if (s.changeStatus != null) 'changeStatus': s.changeStatus!.wire,
      if (s.reasonCode != null) 'reasonCode': s.reasonCode!.value?.wire,
      if (s.policyVersion != null) 'policyVersion': s.policyVersion!.value,
      if (s.mdcSource != null) 'mdcSource': s.mdcSource!.value?.wire,
      if (s.measuredAt != null) 'measuredAt': w.ts(s.measuredAt!),
    };
    w.addExtra(out, s.extra);
    return out;
  }

  static ExerciseAssessment _exerciseAssessment(_MapReader r) =>
      ExerciseAssessment(
        summary: r.string('summary'),
        observations: r.stringList('observations'),
        extra: r.finish(),
      );

  static Map<String, Object?> _encodeExerciseAssessment(
    ExerciseAssessment a,
    _Writer w,
  ) {
    final out = <String, Object?>{
      if (a.summary != null) 'summary': a.summary,
      if (a.observations != null) 'observations': [...a.observations!],
    };
    w.addNestedExtra(out, a.extra, _exerciseAssessmentKeys);
    return out;
  }

  static SoapPlan _plan(_MapReader r) => SoapPlan(
        nextSession: r.string('nextSession'),
        homeExercise: r.string('homeExercise'),
        extra: r.finish(),
      );

  static Map<String, Object?> _encodePlan(SoapPlan p, _Writer w) {
    final out = <String, Object?>{
      if (p.nextSession != null) 'nextSession': p.nextSession,
      if (p.homeExercise != null) 'homeExercise': p.homeExercise,
    };
    w.addNestedExtra(out, p.extra, _planKeys);
    return out;
  }
}

/// `SoapNoteV2Codec.fromMap(data).toMap(target: ...)`.
extension SoapNoteV2Encoding on SoapNoteV2 {
  Map<String, Object?> toMap({CodecTarget target = CodecTarget.firestore}) =>
      SoapNoteV2Codec.toMap(this, target: target);
}

// -------------------------------------------------------------------------------------------
// Reading
// -------------------------------------------------------------------------------------------

E? _wireEnum<E>(Object? value, E? Function(String?) fromWire) =>
    value is String ? fromWire(value) : null;

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}

/// Reads known keys from one map. A known key whose value cannot be read goes to `extra`
/// unchanged, and so does every key that is never read.
class _MapReader {
  _MapReader(Map<dynamic, dynamic> source) : _source = _copyMap(source);

  final Map<String, Object?> _source;
  final Set<String> _read = {};
  final Map<String, Object?> _extra = {};

  /// Returns the value for [key], or [_absent] when the key is missing.
  Object? _take(String key) {
    _read.add(key);
    return _source.containsKey(key) ? _source[key] : _absent;
  }

  T? _keep<T>(String key, Object? value) {
    _extra[key] = value;
    return null;
  }

  String? string(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    return v is String ? v : _keep(key, v);
  }

  Present<String>? nullableString(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v == null) return const Present(null);
    return v is String ? Present(v) : _keep(key, v);
  }

  bool? boolean(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    return v is bool ? v : _keep(key, v);
  }

  int? integer(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    return _asInt(v) ?? _keep(key, v);
  }

  Present<int>? nullableInteger(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v == null) return const Present(null);
    final i = _asInt(v);
    return i != null ? Present(i) : _keep(key, v);
  }

  /// [integer] true: must be integral; false: stored as double; null: keep the runtime type.
  num? number(String key, {bool? integer}) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v is! num || !v.isFinite) return _keep(key, v);
    if (integer == null) return v;
    if (integer) return _asInt(v) ?? _keep(key, v);
    return v.toDouble();
  }

  E? enumValue<E>(String key, E? Function(String?) fromWire) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    return _wireEnum(v, fromWire) ?? _keep(key, v);
  }

  Present<E>? nullableEnum<E>(String key, E? Function(String?) fromWire) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v == null) return Present<E>(null);
    final e = _wireEnum(v, fromWire);
    return e != null ? Present(e) : _keep(key, v);
  }

  SoapTimestamp? timestamp(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v is Timestamp) return SoapTimestamp.instant(v);
    if (v is DateTime) return SoapTimestamp.at(v);
    if (v is FieldValue && v == FieldValue.serverTimestamp()) {
      return const SoapTimestamp.server();
    }
    return _keep(key, v);
  }

  List<String>? stringList(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v is List && v.every((e) => e is String)) {
      return List.unmodifiable(v.cast<String>());
    }
    return _keep(key, v);
  }

  /// A list read element by element. [parse] keeps every element (unreadable ones in a
  /// raw form), so the list keeps its length. A value that is not a list goes to extra.
  List<T>? list<T>(String key, T Function(Object? element) parse) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    if (v is! List) return _keep(key, v);
    return List.unmodifiable([for (final element in v) parse(element)]);
  }

  T? object<T>(String key, T Function(_MapReader r) parse) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    return v is Map ? parse(_MapReader(v)) : _keep(key, v);
  }

  Map<String, Object?>? rawMap(String key) {
    final v = _take(key);
    if (identical(v, _absent)) return null;
    return v is Map ? _copyMap(v) : _keep(key, v);
  }

  /// Unread keys and values that could not be read, in source order.
  Map<String, Object?> finish() {
    final out = <String, Object?>{};
    for (final e in _source.entries) {
      if (!_read.contains(e.key)) {
        out[e.key] = e.value;
      } else if (_extra.containsKey(e.key)) {
        out[e.key] = _extra[e.key];
      }
    }
    return Map.unmodifiable(out);
  }
}

const Object _absent = _Absent();

class _Absent {
  const _Absent();
}

/// Deep, unmodifiable copy with string keys. Leaves Firestore values as they are.
Map<String, Object?> _copyMap(Map<dynamic, dynamic> source) =>
    Map.unmodifiable({
      for (final e in source.entries) '${e.key}': _copyValue(e.value),
    });

Object? _copyValue(Object? value) {
  if (value is Map) return _copyMap(value);
  if (value is List) return List<Object?>.unmodifiable(value.map(_copyValue));
  return value;
}

// -------------------------------------------------------------------------------------------
// Writing
// -------------------------------------------------------------------------------------------

class _Writer {
  _Writer(this.target);

  final CodecTarget target;

  bool get _fixture => target == CodecTarget.fixture;

  Object ts(SoapTimestamp value) => switch (value) {
        SoapInstant(:final timestamp) =>
          _fixture ? {r'$ts': formatFixtureTimestamp(timestamp)} : timestamp,
        SoapServerTimestamp() => _fixture
            ? const {r'$serverTimestamp': true}
            : FieldValue.serverTimestamp(),
      };

  Object integer(int value) => _fixture ? {r'$int': value} : value;

  /// A value that may be fractional: a bare number in fixtures, a double in Firestore.
  Object number(num value) => _fixture ? value : value.toDouble();

  /// Values kept as read (extras, unparsed rows, server-only maps). The runtime type
  /// decides the notation: int -> `$int`, double -> bare number.
  Object? raw(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final e in value.entries) '${e.key}': raw(e.value),
      };
    }
    if (value is List) return [for (final e in value) raw(e)];
    if (!_fixture) return value;
    if (value is int) return {r'$int': value};
    if (value is Timestamp) return {r'$ts': formatFixtureTimestamp(value)};
    if (value is DateTime) {
      return {r'$ts': formatFixtureTimestamp(Timestamp.fromDate(value))};
    }
    if (value is Blob) return {r'$bytes': base64.encode(value.bytes)};
    if (value is FieldValue) {
      if (value == FieldValue.serverTimestamp()) {
        return const {r'$serverTimestamp': true};
      }
      throw ArgumentError.value(value, 'value', 'no fixture notation');
    }
    return value;
  }

  void addExtra(Map<String, Object?> out, Map<String, Object?> extra) {
    for (final e in extra.entries) {
      out[e.key] = raw(e.value);
    }
  }

  /// Nested maps in the rules use `keys().hasOnly([allowed])`. The Firestore target
  /// leaves out extras outside [allowed] (unknown nested keys) and writes back known keys
  /// whose value could not be read, unchanged: Firestore replaces a nested map as a whole,
  /// so dropping them would delete stored data. Fixtures get every extra.
  void addNestedExtra(
    Map<String, Object?> out,
    Map<String, Object?> extra,
    Set<String> allowed,
  ) {
    addExtra(out, {
      for (final e in extra.entries)
        if (_fixture || allowed.contains(e.key)) e.key: e.value,
    });
  }
}

/// `$ts` notation: UTC, seconds, optional fraction without trailing zeros, `Z`.
String formatFixtureTimestamp(Timestamp ts) {
  final t = DateTime.fromMillisecondsSinceEpoch(ts.seconds * 1000, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  final base =
      '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  if (ts.nanoseconds == 0) return '${base}Z';
  final fraction = ts.nanoseconds
      .toString()
      .padLeft(9, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$base.${fraction}Z';
}
