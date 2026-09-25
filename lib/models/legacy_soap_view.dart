// Read-only view of a v1 (legacy) SOAP document (DF-007, AC-SOAP-06.2,
// docs/v1/05_DATA_MODEL_AND_RULES.md §5.6, PRD §11.4).
//
// v1 documents have no `schemaVersion`. The view keeps every `structured.metrics` row and
// shows each one as 'uninterpretable' (해석 불가): no legacy row carries the condition fields
// a v2 metric needs (joint·motion·activeOrPassive, muscleGroup), so even a parsable number
// is not a catalog metric (V1-05 §5.6). Values are never filled with 0.
//
// The view does not expose `diagnosis` (MIG-04) and has no write path.

import 'package:cloud_firestore/cloud_firestore.dart' show Blob, Timestamp;
import 'package:flutter/foundation.dart' show immutable;

import '../contracts/generated/vocab.g.dart' show SoapStatus;

/// How a legacy metric row reads in v2.
enum LegacyMetricInterpretation {
  /// Kept as the original text and shown as '해석 불가' (F-SOAP-06.2).
  uninterpretable,
}

/// One `structured.metrics[]` row of a v1 document, kept as stored.
@immutable
final class LegacyMetricView {
  const LegacyMetricView(this.source);

  /// The stored element. Normally a map with `type, label, side, value, unit, score, note`.
  final Object? source;

  Map<String, Object?> get raw => source is Map
      ? Map<String, Object?>.unmodifiable({
          for (final e in (source as Map).entries) '${e.key}': e.value,
        })
      : const {};

  /// The legacy type as written: `rom`, `ROM`, `통증`, `test`, `general`, ...
  String? get type => _text(raw['type']);
  String? get label => _text(raw['label']);
  String? get side => _text(raw['side']);
  String? get unit => _text(raw['unit']);
  String? get note => _text(raw['note']);

  /// The value as stored (a string in every legacy writer), shown as text.
  String get valueText {
    final value = raw['value'];
    return value == null ? '' : '$value';
  }

  LegacyMetricInterpretation get interpretation =>
      LegacyMetricInterpretation.uninterpretable;

  bool get isInterpretable => false;

  /// The label shown next to the original text.
  String get displayLabel => LegacySoapView.uninterpretableLabel;
}

/// Read-only view of a v1 SOAP document.
@immutable
final class LegacySoapView {
  const LegacySoapView._({
    required this.raw,
    required this.metrics,
    required this.legacyStatus,
    required this.completedCategories,
  });

  /// Reads a v1 document (Firestore types; `$int` millis are ints).
  factory LegacySoapView.fromMap(Map<String, dynamic> data) {
    final raw = Map<String, Object?>.unmodifiable(data);
    final structured = _map(raw['structured']);
    final workflow = _map(structured?['workflow']);
    final rows = structured?['metrics'];
    final categories = workflow?['completedCategories'];
    return LegacySoapView._(
      raw: raw,
      metrics: List.unmodifiable([
        if (rows is List)
          for (final row in rows) LegacyMetricView(row),
      ]),
      legacyStatus: _text(workflow?['status']),
      completedCategories: List.unmodifiable([
        if (categories is List)
          for (final c in categories)
            if (c is String) c,
      ]),
    );
  }

  /// Display label for legacy rows and unknown v2 metric codes.
  static const String uninterpretableLabel = '해석 불가';

  /// The document as read.
  final Map<String, Object?> raw;

  /// Every `structured.metrics` row, in stored order. Never shorter than the stored list.
  final List<LegacyMetricView> metrics;

  /// `structured.workflow.status` as written (`complete`, `완료`, `작성 중`, `공유됨`, ...).
  final String? legacyStatus;

  /// `structured.workflow.completedCategories` as written (`S` or `subjective` style).
  final List<String> completedCategories;

  String? get trainerId => _text(raw['trainerId']);
  String? get memberId => _text(raw['memberId']);

  /// Legacy `date` (epoch millis) as UTC.
  DateTime? get sessionDate {
    final date = raw['date'];
    if (date is int) {
      return DateTime.fromMillisecondsSinceEpoch(date, isUtc: true);
    }
    if (date is Timestamp) return date.toDate().toUtc();
    return null;
  }

  /// v2 status for [legacyStatus] (V1-05 §5.6). Null for a value outside the mapping.
  SoapStatus? get mappedStatus => switch (legacyStatus) {
        null || 'draft' || '작성 중' => SoapStatus.draft,
        'complete' || '완료' || 'shared' || '공유됨' => SoapStatus.finalized,
        _ => null,
      };

  /// The note was shared under v1 (status or flag). v2 does not share it again (MIG-05).
  bool get wasShared =>
      raw['isSharedWithMember'] == true ||
      legacyStatus == 'shared' ||
      legacyStatus == '공유됨';

  /// [completedCategories] with `S·O·A·P` written as `subjective·objective·assessment·plan`.
  List<String> get normalizedCompletedCategories => [
        for (final c in completedCategories) _categoryNames[c] ?? c,
      ];

  /// False for an empty memberId or a local `member-` seed (MIG-07, '회원 연결 없음').
  bool get hasLinkedMember {
    final id = memberId;
    return id != null && id.isNotEmpty && !id.startsWith('member-');
  }

  /// Inline ink (`drawingData` bytes or `structured.subjective.nativeInkDataBase64`).
  /// Read only; v2 keeps ink in Storage (MIG-06).
  bool get hasInlineInk {
    if (raw['drawingData'] is Blob) return true;
    final subjective = _map(_map(raw['structured'])?['subjective']);
    final ink = subjective?['nativeInkDataBase64'];
    return ink is String && ink.isNotEmpty;
  }

  static const Map<String, String> _categoryNames = {
    'S': 'subjective',
    'O': 'objective',
    'A': 'assessment',
    'P': 'plan',
  };
}

String? _text(Object? value) => value is String ? value : null;

Map<Object?, Object?>? _map(Object? value) => value is Map ? value : null;
