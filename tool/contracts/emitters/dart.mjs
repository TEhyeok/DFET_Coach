// Dart emitter (DF-004): lib/contracts/generated/*.g.dart for the Flutter member app.
// Enhanced enums keep the wire string; fromWire returns null for unknown values so callers can keep
// the raw string and show it as '해석 불가' (DF-007 codec), instead of dropping it.
import { METRIC_FIELD_ENUMS, lines, numberLiteral, sqString, statusComment, typeName } from './common.mjs';

export const DART_DIR = 'lib/contracts/generated';

// Dart reserved words, plus members every generated enum already has. A value with one of these
// names gets a `Value` suffix on the Dart side; its wire string is unchanged.
const DART_ESCAPE = new Set([
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum',
  'extends', 'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return',
  'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  'values', 'index', 'name', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod', 'wire', 'fromWire',
  'vocabStatus',
]);

export function dartIdent(value) {
  return DART_ESCAPE.has(value) ? `${value}Value` : value;
}

const str = (s) => sqString(s, { escapeDollar: true });

function enumDecl(name, doc, values, extra = []) {
  return [
    `/// ${doc}`,
    `enum ${name} {`,
    ...values.map((v) => `  ${dartIdent(v)}(${str(v)}),`),
    '  ;',
    '',
    `  const ${name}(this.wire);`,
    '',
    '  /// The string stored in Firestore and in contracts/*.json.',
    '  final String wire;',
    ...extra,
    '',
    '  /// Returns null for a missing or unknown value. Callers keep the raw string (해석 불가).',
    `  static ${name}? fromWire(String? value) {`,
    `    for (final candidate in ${name}.values) {`,
    '      if (candidate.wire == value) return candidate;',
    '    }',
    '    return null;',
    '  }',
    '}',
  ];
}

// Generated layout is fixed by the emitter; `dart format` must not rewrite it (that would be drift).
const FORMAT_OFF = '// dart format off';

const header = (doc) => [
  FORMAT_OFF,
  `// contract ${doc.contract} v${doc.version} revision ${doc.revision}. Regenerate with: node tool/contracts/generate.mjs`,
];

export function renderVocab({ vocab }) {
  const doc = vocab.doc;
  const out = [
    ...header(doc),
    '',
    '/// Whether a vocab block is confirmed or still a draft (V1-05 §13.2).',
    'enum VocabStatus { confirmed, draft }',
  ];
  for (const [key, entry] of Object.entries(doc.enums)) {
    out.push(
      '',
      ...enumDecl(typeName(key), `vocab \`${key}\` (${statusComment(entry)}).`, entry.values, [
        '',
        `  static const VocabStatus vocabStatus = VocabStatus.${entry.status};`,
      ]),
    );
  }
  const pairs = doc.jointMotionPairs;
  out.push(
    '',
    '/// Allowed motions for one joint (vocab `jointMotionPairs`).',
    'class JointMotionPair {',
    '  const JointMotionPair({required this.joint, required this.motions});',
    '',
    '  final Joint joint;',
    '  final List<Motion> motions;',
    '}',
    '',
    `/// vocab \`jointMotionPairs\` (${statusComment(pairs)}). While draft the list may be empty and codecs do not check pairs (ASM-P0-04).`,
    'abstract final class JointMotionPairs {',
    `  static const VocabStatus vocabStatus = VocabStatus.${pairs.status};`,
  );
  if (pairs.pairs.length === 0) {
    out.push('  static const List<JointMotionPair> pairs = [];');
  } else {
    out.push('  static const List<JointMotionPair> pairs = [');
    for (const p of pairs.pairs) {
      out.push(
        '    JointMotionPair(',
        `      joint: Joint.${dartIdent(p.joint)},`,
        ...listField('      ', 'motions', p.motions.map((m) => `Motion.${dartIdent(m)}`)),
        '    ),',
      );
    }
    out.push('  ];');
  }
  out.push('}');
  return lines(out);
}

// `name: [` ... `],` with one item per line and a trailing comma, so `dart format` (short style,
// language version 3.0) keeps the layout. Empty lists stay inline.
function listField(indent, name, items) {
  if (items.length === 0) return [`${indent}${name}: [],`];
  return [`${indent}${name}: [`, ...items.map((item) => `${indent}  ${item},`), `${indent}],`];
}

// `decl = [` ... `];` in the same one-item-per-line layout.
function constList(indent, decl, items) {
  if (items.length === 0) return [`${indent}${decl} = [];`];
  return [`${indent}${decl} = [`, ...items.map((item) => `${indent}  ${item},`), `${indent}];`];
}

// `name: Ctor(` ... `),` with one named argument per line.
function callField(indent, name, ctor, args) {
  return [`${indent}${name}: ${ctor}(`, ...args.map(([k, v]) => `${indent}  ${k}: ${v},`), `${indent}),`];
}

function entryLiteral(m) {
  const t = (field) => typeName(METRIC_FIELD_ENUMS[field]);
  const ref = (field, v) => `${t(field)}.${dartIdent(v)}`;
  const i = '      ';
  const refs = (field) => m[field].map((v) => ref(field, v));
  const range = m.range === null
    ? [`${i}range: null,`]
    : callField(i, 'range', 'MetricRange', [
      ['min', numberLiteral(m.range.min)],
      ['minExclusive', String(m.range.minExclusive)],
      ['max', numberLiteral(m.range.max)],
      ['appMin', numberLiteral(m.range.appMin)],
    ]);
  return [
    '    MetricCatalogEntry(',
    `${i}code: MetricCode.${dartIdent(m.metricCode)},`,
    `${i}nameKo: ${str(m.nameKo)},`,
    `${i}family: ${ref('family', m.family)},`,
    `${i}unit: ${ref('unit', m.unit)},`,
    `${i}decimals: ${m.decimals},`,
    `${i}scale: ${ref('scale', m.scale)},`,
    `${i}sideRule: ${ref('sideRule', m.sideRule)},`,
    ...listField(i, 'allowedSourceGrades', refs('allowedSourceGrades')),
    ...listField(i, 'screeningOnlySourceGrades', refs('screeningOnlySourceGrades')),
    ...listField(i, 'betaSourceGrades', refs('betaSourceGrades')),
    `${i}reliabilityTier: ${m.reliabilityTier === null ? 'null' : ref('reliabilityTier', m.reliabilityTier)},`,
    `${i}improvementDirection: ${ref('improvementDirection', m.improvementDirection)},`,
    ...listField(i, 'conditionKeys', m.conditionKeys.map(str)),
    `${i}availability: ${ref('availability', m.availability)},`,
    `${i}judgeAs: ${m.judgeAs === null ? 'null' : `MetricCode.${dartIdent(m.judgeAs)}`},`,
    ...callField(i, 'storage', 'MetricStorage', [
      ['collection', str(m.storage.collection)],
      ['field', str(m.storage.field)],
    ]),
    ...range,
    '    ),',
  ];
}

export function renderMetricCatalog({ metricCatalog }) {
  const doc = metricCatalog.doc;
  const t = (field) => typeName(METRIC_FIELD_ENUMS[field]);
  const out = [
    ...header(doc),
    '',
    "import 'vocab.g.dart';",
    '',
    ...enumDecl('MetricCode', 'Metric codes in PRD appendix A.1 order (`metrics[].metricCode`).', doc.metrics.map((m) => m.metricCode)),
    '',
    '/// Where the raw record stores the value (`storage`).',
    'class MetricStorage {',
    '  const MetricStorage({required this.collection, required this.field});',
    '',
    '  final String collection;',
    '  final String field;',
    '}',
    '',
    '/// Rule range copied from V1-05 §4.7/§4.8/§5.2 (`range`).',
    'class MetricRange {',
    '  const MetricRange({',
    '    required this.min,',
    '    required this.minExclusive,',
    '    required this.max,',
    '    required this.appMin,',
    '  });',
    '',
    '  final double min;',
    '  final bool minExclusive;',
    '  final double max;',
    '  final double appMin;',
    '}',
    '',
    '/// One `metrics[]` entry of contracts/metric-catalog.v1.json.',
    'class MetricCatalogEntry {',
    '  const MetricCatalogEntry({',
    '    required this.code,',
    '    required this.nameKo,',
    '    required this.family,',
    '    required this.unit,',
    '    required this.decimals,',
    '    required this.scale,',
    '    required this.sideRule,',
    '    required this.allowedSourceGrades,',
    '    required this.screeningOnlySourceGrades,',
    '    required this.betaSourceGrades,',
    '    required this.reliabilityTier,',
    '    required this.improvementDirection,',
    '    required this.conditionKeys,',
    '    required this.availability,',
    '    required this.judgeAs,',
    '    required this.storage,',
    '    required this.range,',
    '  });',
    '',
    '  final MetricCode code;',
    '  final String nameKo;',
    `  final ${t('family')} family;`,
    `  final ${t('unit')} unit;`,
    '  final int decimals;',
    `  final ${t('scale')} scale;`,
    `  final ${t('sideRule')} sideRule;`,
    `  final List<${t('allowedSourceGrades')}> allowedSourceGrades;`,
    `  final List<${t('screeningOnlySourceGrades')}> screeningOnlySourceGrades;`,
    `  final List<${t('betaSourceGrades')}> betaSourceGrades;`,
    `  final ${t('reliabilityTier')}? reliabilityTier;`,
    `  final ${t('improvementDirection')} improvementDirection;`,
    '  final List<String> conditionKeys;',
    `  final ${t('availability')} availability;`,
    '  final MetricCode? judgeAs;',
    '  final MetricStorage storage;',
    '  final MetricRange? range;',
    '}',
    '',
    'abstract final class MetricCatalog {',
    '  /// Reserved or excluded codes (PRD appendix A.4). Codecs and rules reject them.',
    ...constList('  ', 'static const List<String> excludedMetricCodes', doc.excludedMetricCodes.map(str)),
    '',
    '  /// All entries in `MetricCode.values` order.',
    '  static const List<MetricCatalogEntry> all = [',
  ];
  for (const m of doc.metrics) out.push(...entryLiteral(m));
  out.push('  ];', '', '  static MetricCatalogEntry entry(MetricCode code) => all[code.index];', '}');
  return lines(out);
}

export function renderContractsVersion(ctx) {
  const out = [
    FORMAT_OFF,
    '',
    '/// Version and input hash of one contracts/*.json file.',
    'class ContractVersion {',
    '  const ContractVersion({',
    '    required this.contract,',
    '    required this.version,',
    '    required this.revision,',
    '    required this.sha256,',
    '  });',
    '',
    '  final String contract;',
    '  final int version;',
    '  final int revision;',
    '',
    '  /// First 12 hex digits of the sha256 of the input file bytes.',
    '  final String sha256;',
    '}',
    '',
    'abstract final class ContractsVersion {',
  ];
  const names = [];
  for (const input of ctx.present) {
    const { doc } = input;
    names.push(input.key);
    out.push(
      `  static const ${input.key} = ContractVersion(`,
      `    contract: ${str(doc.contract)},`,
      `    version: ${doc.version},`,
      `    revision: ${doc.revision},`,
      `    sha256: ${str(input.sha12)},`,
      '  );',
    );
  }
  out.push('', `  static const List<ContractVersion> all = [${names.join(', ')}];`, '}');
  return lines(out);
}

export const dartEmitters = Object.freeze({
  vocab: { id: 'dart.vocab', path: `${DART_DIR}/vocab.g.dart`, comment: '//', uses: ['vocab'], render: renderVocab },
  metricCatalog: {
    id: 'dart.metricCatalog',
    path: `${DART_DIR}/metric_catalog.g.dart`,
    comment: '//',
    uses: ['metricCatalog'],
    render: renderMetricCatalog,
  },
  contractsVersion: {
    id: 'dart.contractsVersion',
    path: `${DART_DIR}/contracts_version.g.dart`,
    comment: '//',
    uses: ['metricCatalog', 'vocab'],
    partial: true,
    render: renderContractsVersion,
  },
});
