// Fixture I/O for the Dart SOAP codec tests (DF-007).
//
// Reads contracts/fixtures/** from the repository root (flutter test runs there), splits the
// envelope {_fixture, path, data} and turns the four type tags of the P0 DF-005 fixture
// contract (rule 2) into Firestore types:
//   {"$ts": "..."}              -> Timestamp
//   {"$serverTimestamp": true}  -> FieldValue.serverTimestamp()
//   {"$bytes": "<base64>"}      -> Blob
//   {"$int": n}                 -> int
//   bare number                 -> double
// Any other `$` key fails (V1-10 §6.1).
//
// Record mode: DFET_RECORD_FIXTURES=1 writes record-mode outputs in the fixture format
// (JSON.stringify(doc, null, 2) + "\n", contracts/fixtures/README.md §5).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

final Directory fixturesDir = Directory('contracts/fixtures');

/// True when `DFET_RECORD_FIXTURES=1`. CI never sets it.
bool get recordMode => Platform.environment['DFET_RECORD_FIXTURES'] == '1';

/// One fixture file.
class FixtureFile {
  FixtureFile._(this.file, this.envelope);

  factory FixtureFile.load(File file) {
    final doc = jsonDecode(file.readAsStringSync());
    if (doc is! Map<String, dynamic>) {
      throw FormatException('${file.path}: top level is not an object');
    }
    final keys = doc.keys.toList();
    if (keys.length != 3 || !keys.toSet().containsAll(_envelopeKeys)) {
      throw FormatException(
          '${file.path}: envelope keys $keys, expected $_envelopeKeys');
    }
    return FixtureFile._(file, doc);
  }

  static const _envelopeKeys = {'_fixture', 'path', 'data'};

  final File file;
  final Map<String, dynamic> envelope;

  /// `soap_v2/draft_rom_mmt_pain` style ID (relative path without `.json`).
  String get id => _fixture['id'] as String;

  /// File name without `.json`.
  String get base =>
      file.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), '');

  Map<String, dynamic> get _fixture =>
      envelope['_fixture'] as Map<String, dynamic>;
  String get writer => _fixture['writer'] as String;
  List<String> get prdRefs => (_fixture['prdRefs'] as List).cast<String>();
  Map<String, dynamic> get expect => _fixture['expect'] as Map<String, dynamic>;
  String get path => envelope['path'] as String;

  /// `data` in fixture notation, as written in the file.
  Map<String, dynamic> get taggedData =>
      envelope['data'] as Map<String, dynamic>;

  /// `data` with tags turned into Firestore types (the codec's input).
  Map<String, dynamic> get data =>
      decodeTags(taggedData) as Map<String, dynamic>;
}

/// Every `*.json` directly under `contracts/fixtures/<group>/`, sorted by name.
List<FixtureFile> loadFixtureGroup(String group) {
  final dir = Directory('${fixturesDir.path}/$group');
  if (!dir.existsSync()) {
    throw StateError(
        '${dir.path} not found. Run flutter test from the repository root.');
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) FixtureFile.load(f)];
}

File fixtureFile(String relativePath) =>
    File('${fixturesDir.path}/$relativePath');

// -------------------------------------------------------------------------------------------
// Tags
// -------------------------------------------------------------------------------------------

const Set<String> fixtureTags = {
  r'$ts',
  r'$serverTimestamp',
  r'$bytes',
  r'$int'
};

/// Fixture notation -> Firestore types.
Object? decodeTags(Object? json, [String at = 'data']) {
  if (json is Map) {
    final tagKeys = json.keys.where((k) => '$k'.startsWith(r'$')).toList();
    if (tagKeys.isNotEmpty) return _decodeTag(json, at);
    return <String, dynamic>{
      for (final e in json.entries)
        '${e.key}': decodeTags(e.value, '$at/${e.key}'),
    };
  }
  if (json is List) {
    return [
      for (var i = 0; i < json.length; i++) decodeTags(json[i], '$at/$i')
    ];
  }
  if (json is num) return json.toDouble();
  return json;
}

Object _decodeTag(Map<dynamic, dynamic> tag, String at) {
  if (tag.length != 1) {
    throw FormatException('$at: tag object must have one key: $tag');
  }
  final key = '${tag.keys.single}';
  final value = tag.values.single;
  switch (key) {
    case r'$ts':
      if (value is String) return parseFixtureTimestamp(value, at);
    case r'$serverTimestamp':
      if (value == true) return FieldValue.serverTimestamp();
    case r'$bytes':
      if (value is String) {
        return Blob(Uint8List.fromList(base64.decode(value)));
      }
    case r'$int':
      if (value is int) return value;
    default:
      throw FormatException('$at: unknown tag $key (allowed: $fixtureTags)');
  }
  throw FormatException('$at: bad $key value $value');
}

final RegExp _iso8601 = RegExp(
  r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$',
);

/// `$ts` value -> Timestamp, keeping nanoseconds. The offset only locates the instant.
Timestamp parseFixtureTimestamp(String value, [String at = r'$ts']) {
  final m = _iso8601.firstMatch(value);
  if (m == null) {
    throw FormatException('$at: \$ts is not ISO 8601 with Z or offset: $value');
  }
  final whole = DateTime.parse('${m[1]}${m[3]}');
  final nanos = int.parse((m[2] ?? '').padRight(9, '0'));
  return Timestamp(whole.millisecondsSinceEpoch ~/ 1000, nanos);
}

// -------------------------------------------------------------------------------------------
// Structural comparison (AC-DF-007.1)
// -------------------------------------------------------------------------------------------

/// Differences between two values in fixture notation, one line per difference.
///
/// - Key order is ignored; a missing key and a null value are different.
/// - Numbers compare by value (45 == 45.0, |a - b| < 1e-9). `{"$int": 4}` is a map, so it
///   only equals `{"$int": 4}`, never a bare 4.
/// - `$ts` values compare as instants (a Firestore Timestamp has no offset).
/// - Strings compare exactly. The codec does not change strings, so no NFC step is needed.
List<String> structuralDiff(Object? actual, Object? expected,
    [String at = 'data']) {
  final out = <String>[];
  _diff(actual, expected, at, out);
  return out;
}

void _diff(Object? a, Object? e, String at, List<String> out) {
  if (a is num && e is num) {
    if ((a - e).abs() >= 1e-9) out.add('$at: $a != $e');
    return;
  }
  if (a is Map && e is Map) {
    if (_isTs(a) && _isTs(e)) {
      final ta = parseFixtureTimestamp(a[r'$ts'] as String, at);
      final te = parseFixtureTimestamp(e[r'$ts'] as String, at);
      if (ta != te) out.add('$at: \$ts ${a[r'$ts']} != ${e[r'$ts']}');
      return;
    }
    for (final k in e.keys) {
      if (!a.containsKey(k)) {
        out.add('$at/$k: missing (expected ${jsonEncode(e[k])})');
      }
    }
    for (final k in a.keys) {
      if (!e.containsKey(k)) {
        out.add('$at/$k: unexpected ${jsonEncode(a[k])}');
      } else {
        _diff(a[k], e[k], '$at/$k', out);
      }
    }
    return;
  }
  if (a is List && e is List) {
    if (a.length != e.length) {
      out.add('$at: length ${a.length} != ${e.length}');
      return;
    }
    for (var i = 0; i < a.length; i++) {
      _diff(a[i], e[i], '$at/$i', out);
    }
    return;
  }
  if (a != e) out.add('$at: ${jsonEncode(a)} != ${jsonEncode(e)}');
}

bool _isTs(Map<dynamic, dynamic> m) => m.length == 1 && m.containsKey(r'$ts');

// -------------------------------------------------------------------------------------------
// Writing (record mode)
// -------------------------------------------------------------------------------------------

/// `JSON.stringify(doc, null, 2) + "\n"`: integral doubles print as integers.
String canonicalFixtureJson(Object? doc) =>
    '${const JsonEncoder.withIndent('  ').convert(_jsNumbers(doc))}\n';

Object? _jsNumbers(Object? v) {
  if (v is Map) {
    return {for (final e in v.entries) '${e.key}': _jsNumbers(e.value)};
  }
  if (v is List) return [for (final e in v) _jsNumbers(e)];
  if (v is double &&
      v.isFinite &&
      v == v.roundToDouble() &&
      v.abs() < 9007199254740992) {
    return v.toInt();
  }
  return v;
}

/// The record-mode envelope for `soap_v2/<name>.json` (writer `dart`).
Map<String, Object?> recordedEnvelope({
  required String name,
  required String description,
  required List<String> prdRefs,
  required Map<String, dynamic> expect,
  required String path,
  required Map<String, Object?> data,
}) =>
    {
      '_fixture': {
        'id': 'soap_v2/$name',
        'description': description,
        'writer': 'dart',
        'prdRefs': prdRefs,
        'expect': expect,
      },
      'path': path,
      'data': data,
    };
