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

// Static members the Swift enums already declare. A case with one of these names is an invalid
// redeclaration (`vocabStatus` only exists on vocab enums).
const SWIFT_ENUM_MEMBERS = ['allCases'];
const SWIFT_VOCAB_ENUM_MEMBERS = ['vocabStatus'];

// Values of one enum whose Swift case name clashes with another case or a generated member.
export function swiftIdentCollisions(values, { vocab = false } = {}) {
  const members = vocab ? [...SWIFT_ENUM_MEMBERS, ...SWIFT_VOCAB_ENUM_MEMBERS] : SWIFT_ENUM_MEMBERS;
  const seen = new Map(members.map((m) => [m, null]));
  const found = [];
  values.forEach((value, index) => {
    if (seen.has(value)) {
      const other = seen.get(value);
      found.push({ index, value, ident: value, other: other === null ? `generated member ${value}` : values[other] });
    } else {
      seen.set(value, index);
    }
  });
  return found;
}

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

// contracts/prohibited-terms.v1.json -> ProhibitedTerms.swift (DF-010). Data only: the matcher that uses it
// (TrainerDomain CopyGuard, TR-05 inline warnings) is DF-120. Matching rules: docs/v1/12 §7.3.
function termRuleInit(r, indent) {
  const t = `${indent}  `;
  return [
    `${indent}TermRule(`,
    `${t}id: ${dqString(r.id)},`,
    `${t}terms: ${stringList(r.terms)},`,
    `${t}regex: ${stringList(r.regex ?? [])},`,
    `${t}alternatives: ${stringList(r.alternatives)},`,
    `${t}severity: .${r.severity},`,
    `${t}boundary: .${r.match?.boundary ?? 'anywhere'},`,
    `${t}except: ${stringList(r.match?.except ?? [])},`,
    `${t}onlyInKeyPrefixes: ${r.onlyIn ? stringList(r.onlyIn.keyPrefixes) : 'nil'},`,
    `${t}onlyInGlobs: ${r.onlyIn ? stringList(r.onlyIn.globs) : 'nil'}`,
    `${indent}),`,
  ];
}

function ruleList(name, doc, rules) {
  if (rules.length === 0) return [`  /// ${doc}`, `  public static let ${name}: [TermRule] = []`];
  return [`  /// ${doc}`, `  public static let ${name}: [TermRule] = [`, ...rules.flatMap((r) => termRuleInit(r, '    ')), '  ]'];
}

export function renderProhibitedTerms({ prohibitedTerms }) {
  const doc = prohibitedTerms.doc;
  const out = [
    `// contract ${doc.contract} v${doc.version} revision ${doc.revision}. Regenerate with: node tool/contracts/generate.mjs`,
    '// PRD appendix C as data. Matching rules (normalization, optional spacing, wordStart, except): docs/v1/12 §7.3.',
    '',
    '/// `block` stops sharing and fails copy-lint in block mode; `warn` is reported only.',
    'public enum TermSeverity: String, Sendable {',
    '  case block',
    '  case warn',
    '}',
    '',
    '/// `wordStart`: a match preceded by a Hangul letter or an ASCII letter/digit is ignored.',
    'public enum TermBoundary: String, Sendable {',
    '  case anywhere',
    '  case wordStart',
    '}',
    '',
    '/// One rule of `ruleSets.common`, `ruleSets.member` or `ruleSets.trainer`.',
    'public struct TermRule: Sendable, Equatable {',
    '  public let id: String',
    '  /// A space inside a term also matches no space or one of `· - _ /`.',
    '  public let terms: [String]',
    '  /// Extra patterns (JavaScript syntax, case-insensitive), e.g. accuracy percentages.',
    '  public let regex: [String]',
    '  public let alternatives: [String]',
    '  public let severity: TermSeverity',
    '  public let boundary: TermBoundary',
    '  /// A match that lies entirely inside one of these phrases is ignored.',
    '  public let except: [String]',
    '  /// When non-nil the rule applies only to catalog keys with one of these prefixes',
    '  /// or to files under one of `onlyInGlobs`.',
    '  public let onlyInKeyPrefixes: [String]?',
    '  public let onlyInGlobs: [String]?',
    '}',
    '',
    '/// Appendix C.2 cause-and-effect pattern. Always a warning (ASM-P0-07).',
    'public struct TermCausalPattern: Sendable, Equatable {',
    '  public let id: String',
    '  public let regex: String',
    '  public let allowedExample: String',
    '}',
    '',
    '/// An active exact-string exception (PRD §3.1 disclaimers). The rules are dropped only when the',
    '/// whole normalized string equals `exactString`.',
    'public struct TermAllowEntry: Sendable, Equatable {',
    '  public let id: String',
    '  public let exactString: String',
    '  public let rules: [String]',
    '}',
    '',
    'public enum ProhibitedTerms {',
    `  public static let version = ${doc.version}`,
    `  public static let revision = ${doc.revision}`,
    '',
    ...ruleList('common', 'Appendix C.1: every user-facing string.', doc.ruleSets.common),
    '',
    ...ruleList('member', 'Appendix C.3 member-facing additions.', doc.ruleSets.member),
    '',
    ...ruleList('trainer', 'Appendix C.3 trainer additions (none: the trainer set is `common` only).', doc.ruleSets.trainer),
    '',
    '  /// Appendix C.2 patterns (warnings).',
    '  public static let causalPatterns: [TermCausalPattern] = [',
    ...doc.causalPatterns.map((p) => `    TermCausalPattern(id: ${dqString(p.id)}, regex: ${dqString(p.regex)}, allowedExample: ${dqString(p.allowedExample)}),`),
    '  ]',
    '',
    '  /// Abbreviations trainers may use in their own records (appendix B.8).',
    `  public static let trainerAbbreviations: [String] = ${stringList(doc.abbreviationAllowlist.trainer)}`,
    '',
    '  /// Active `allowEntries`.',
    '  public static let allowEntries: [TermAllowEntry] = [',
    ...doc.allowEntries.filter((e) => e.active).map((e) => `    TermAllowEntry(id: ${dqString(e.id)}, exactString: ${dqString(e.exactString)}, rules: ${stringList(e.rules)}),`),
    '  ]',
    '}',
  ];
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
  prohibitedTerms: {
    id: 'swift.prohibitedTerms',
    path: `${SWIFT_DIR}/ProhibitedTerms.swift`,
    comment: '//',
    uses: ['prohibitedTerms'],
    render: renderProhibitedTerms,
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
