// Swift emitter (DF-004): trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/*.swift
// Pure Swift (no Foundation import) so TrainerContracts stays a pure target (ADR-001 §3-3, V1-04 §6.2).
import { METRIC_FIELD_ENUMS, dqString, lines, numberLiteral, statusComment, typeName } from './common.mjs';

export const SWIFT_DIR = 'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated';

// Swift keywords plus names that are ambiguous as enum cases (`none` shadows Optional.none).
const SWIFT_ESCAPE = new Set([
  'associatedtype', 'class', 'deinit', 'enum', 'extension', 'fileprivate', 'func', 'import', 'init',
  'inout', 'internal', 'let', 'open', 'operator', 'private', 'precedencegroup', 'protocol', 'public',
  'rethrows', 'static', 'struct', 'subscript', 'typealias', 'var', 'break', 'case', 'catch', 'continue',
  'default', 'defer', 'do', 'else', 'fallthrough', 'for', 'guard', 'if', 'in', 'repeat', 'return',
  'throw', 'switch', 'where', 'while', 'as', 'await', 'false', 'is', 'nil', 'self', 'super', 'throws',
  'true', 'try', 'none', 'some', 'any',
]);

export function swiftCase(value) {
  return SWIFT_ESCAPE.has(value) ? `\`${value}\`` : value;
}

// Enum case declaration. Escaped names carry an explicit raw value so the wire string is obvious.
function caseDecl(value) {
  return SWIFT_ESCAPE.has(value) ? `  case \`${value}\` = ${dqString(value)}` : `  case ${value}`;
}

const INDENT = '  ';

function enumDecl(name, doc, values, extra = []) {
  return [
    `/// ${doc}`,
    `public enum ${name}: String, Codable, CaseIterable, Sendable {`,
    ...values.map(caseDecl),
    ...(extra.length ? ['', ...extra] : []),
    '}',
  ];
}

export function renderVocab({ vocab }) {
  const doc = vocab.doc;
  const out = [
    `// contract ${doc.contract} v${doc.version} revision ${doc.revision}. Regenerate with: node tool/contracts/generate.mjs`,
    '',
    '/// Whether a vocab block is confirmed or still a draft (V1-05 §13.2).',
    'public enum VocabStatus: String, Codable, CaseIterable, Sendable {',
    '  case confirmed',
    '  case draft',
    '}',
  ];
  for (const [key, entry] of Object.entries(doc.enums)) {
    out.push(
      '',
      ...enumDecl(typeName(key), `vocab \`${key}\` (${statusComment(entry)}).`, entry.values, [
        `${INDENT}public static let vocabStatus: VocabStatus = .${entry.status}`,
      ]),
    );
  }
  const pairs = doc.jointMotionPairs;
  out.push(
    '',
    '/// Allowed motions for one joint (vocab `jointMotionPairs`).',
    'public struct JointMotionPair: Sendable, Equatable {',
    '  public let joint: Joint',
    '  public let motions: [Motion]',
    '}',
    '',
    `/// vocab \`jointMotionPairs\` (${statusComment(pairs)}). While draft the list may be empty and codecs do not check pairs (ASM-P0-04).`,
    'public enum JointMotionPairs {',
    `  public static let vocabStatus: VocabStatus = .${pairs.status}`,
  );
  if (pairs.pairs.length === 0) {
    out.push('  public static let pairs: [JointMotionPair] = []');
  } else {
    out.push('  public static let pairs: [JointMotionPair] = [');
    for (const p of pairs.pairs) {
      const motions = p.motions.map((m) => `.${swiftCase(m)}`).join(', ');
      out.push(`    JointMotionPair(joint: .${swiftCase(p.joint)}, motions: [${motions}]),`);
    }
    out.push('  ]');
  }
  out.push('}');
  return lines(out);
}

function enumRef(value) {
  return `.${swiftCase(value)}`;
}

function enumList(values) {
  return `[${values.map((v) => `.${swiftCase(v)}`).join(', ')}]`;
}

function stringList(values) {
  return `[${values.map(dqString).join(', ')}]`;
}

function entryInit(m) {
  const t = '        ';
  const range = m.range === null
    ? 'nil'
    : `MetricRange(min: ${numberLiteral(m.range.min)}, minExclusive: ${m.range.minExclusive}, max: ${numberLiteral(m.range.max)}, appMin: ${numberLiteral(m.range.appMin)})`;
  return [
    `      return MetricCatalogEntry(`,
    `${t}code: .${swiftCase(m.metricCode)},`,
    `${t}nameKo: ${dqString(m.nameKo)},`,
    `${t}family: ${enumRef(m.family)},`,
    `${t}unit: ${enumRef(m.unit)},`,
    `${t}decimals: ${m.decimals},`,
    `${t}scale: ${enumRef(m.scale)},`,
    `${t}sideRule: ${enumRef(m.sideRule)},`,
    `${t}allowedSourceGrades: ${enumList(m.allowedSourceGrades)},`,
    `${t}screeningOnlySourceGrades: ${enumList(m.screeningOnlySourceGrades)},`,
    `${t}betaSourceGrades: ${enumList(m.betaSourceGrades)},`,
    `${t}reliabilityTier: ${m.reliabilityTier === null ? 'nil' : enumRef(m.reliabilityTier)},`,
    `${t}improvementDirection: ${enumRef(m.improvementDirection)},`,
    `${t}conditionKeys: ${stringList(m.conditionKeys)},`,
    `${t}availability: ${enumRef(m.availability)},`,
    `${t}judgeAs: ${m.judgeAs === null ? 'nil' : `.${swiftCase(m.judgeAs)}`},`,
    `${t}storage: MetricStorage(collection: ${dqString(m.storage.collection)}, field: ${dqString(m.storage.field)}),`,
    `${t}range: ${range}`,
    '      )',
  ];
}

export function renderMetricCatalog({ metricCatalog }) {
  const doc = metricCatalog.doc;
  const t = (field) => typeName(METRIC_FIELD_ENUMS[field]);
  const out = [
    `// contract ${doc.contract} v${doc.version} revision ${doc.revision}. Regenerate with: node tool/contracts/generate.mjs`,
    '',
    ...enumDecl('MetricCode', 'Metric codes in PRD appendix A.1 order (`metrics[].metricCode`).', doc.metrics.map((m) => m.metricCode)),
    '',
    '/// Where the raw record stores the value (`storage`).',
    'public struct MetricStorage: Sendable, Equatable {',
    '  public let collection: String',
    '  public let field: String',
    '}',
    '',
    '/// Rule range copied from V1-05 §4.7/§4.8/§5.2 (`range`).',
    'public struct MetricRange: Sendable, Equatable {',
    '  public let min: Double',
    '  public let minExclusive: Bool',
    '  public let max: Double',
    '  public let appMin: Double',
    '}',
    '',
    '/// One `metrics[]` entry of contracts/metric-catalog.v1.json.',
    'public struct MetricCatalogEntry: Sendable, Equatable {',
    '  public let code: MetricCode',
    '  public let nameKo: String',
    `  public let family: ${t('family')}`,
    `  public let unit: ${t('unit')}`,
    '  public let decimals: Int',
    `  public let scale: ${t('scale')}`,
    `  public let sideRule: ${t('sideRule')}`,
    `  public let allowedSourceGrades: [${t('allowedSourceGrades')}]`,
    `  public let screeningOnlySourceGrades: [${t('screeningOnlySourceGrades')}]`,
    `  public let betaSourceGrades: [${t('betaSourceGrades')}]`,
    `  public let reliabilityTier: ${t('reliabilityTier')}?`,
    `  public let improvementDirection: ${t('improvementDirection')}`,
    '  public let conditionKeys: [String]',
    `  public let availability: ${t('availability')}`,
    '  public let judgeAs: MetricCode?',
    '  public let storage: MetricStorage',
    '  public let range: MetricRange?',
    '}',
    '',
    'public enum MetricCatalog {',
    '  /// Reserved or excluded codes (PRD appendix A.4). Codecs and rules reject them.',
    `  public static let excludedMetricCodes: [String] = ${stringList(doc.excludedMetricCodes)}`,
    '',
    '  /// All entries in `MetricCode.allCases` order.',
    '  public static let all: [MetricCatalogEntry] = MetricCode.allCases.map { MetricCatalog.entry(for: $0) }',
    '',
    '  public static func entry(for code: MetricCode) -> MetricCatalogEntry {',
    '    switch code {',
  ];
  for (const m of doc.metrics) {
    out.push(`    case .${swiftCase(m.metricCode)}:`, ...entryInit(m));
  }
  out.push('    }', '  }', '}');
  return lines(out);
}

export function renderContractsVersion(ctx) {
  const out = [
    '/// Version and input hash of one contracts/*.json file.',
    'public struct ContractVersion: Sendable, Equatable {',
    '  public let contract: String',
    '  public let version: Int',
    '  public let revision: Int',
    '  /// First 12 hex digits of the sha256 of the input file bytes.',
    '  public let sha256: String',
    '}',
    '',
    'public enum ContractsVersion {',
  ];
  const names = [];
  for (const input of ctx.present) {
    const { doc } = input;
    names.push(input.key);
    out.push(
      `  public static let ${input.key} = ContractVersion(contract: ${dqString(doc.contract)}, version: ${doc.version}, revision: ${doc.revision}, sha256: ${dqString(input.sha12)})`,
    );
  }
  out.push('', `  public static let all: [ContractVersion] = [${names.join(', ')}]`, '}');
  return lines(out);
}

export const swiftEmitters = Object.freeze({
  vocab: { id: 'swift.vocab', path: `${SWIFT_DIR}/Vocab.swift`, comment: '//', uses: ['vocab'], render: renderVocab },
  metricCatalog: {
    id: 'swift.metricCatalog',
    path: `${SWIFT_DIR}/MetricCatalog.swift`,
    comment: '//',
    uses: ['metricCatalog'],
    render: renderMetricCatalog,
  },
  contractsVersion: {
    id: 'swift.contractsVersion',
    path: `${SWIFT_DIR}/ContractsVersion.swift`,
    comment: '//',
    uses: ['metricCatalog', 'vocab'],
    partial: true,
    render: renderContractsVersion,
  },
});
