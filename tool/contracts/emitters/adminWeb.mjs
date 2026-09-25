// admin_web emitter (DF-004): admin_web/lib/generated/contracts.ts.
// `as const` value lists plus derived union types, for zod schemas (z.enum(SOURCE_GRADES)).
import { FEATURE_FLAG_PHASES, METRIC_FIELD_ENUMS, lines, numberLiteral, pluralConstName, sqString, typeName } from './common.mjs';

export const ADMIN_WEB_DIR = 'admin_web/lib/generated';

const str = (s) => sqString(s);

function constList(name, values) {
  if (values.length === 0) return [`export const ${name} = [] as const;`];
  return [`export const ${name} = [`, ...values.map((v) => `  ${str(v)},`), '] as const;'];
}

function entryLiteral(m) {
  const i = '    ';
  const list = (vs) => `[${vs.map(str).join(', ')}]`;
  const nullable = (v) => (v === null ? 'null' : str(v));
  const range = m.range === null
    ? 'null'
    : `{ min: ${numberLiteral(m.range.min)}, minExclusive: ${m.range.minExclusive}, max: ${numberLiteral(m.range.max)}, appMin: ${numberLiteral(m.range.appMin)} }`;
  return [
    `  ${m.metricCode}: {`,
    `${i}metricCode: ${str(m.metricCode)},`,
    `${i}nameKo: ${str(m.nameKo)},`,
    `${i}family: ${str(m.family)},`,
    `${i}unit: ${str(m.unit)},`,
    `${i}decimals: ${m.decimals},`,
    `${i}scale: ${str(m.scale)},`,
    `${i}sideRule: ${str(m.sideRule)},`,
    `${i}allowedSourceGrades: ${list(m.allowedSourceGrades)},`,
    `${i}screeningOnlySourceGrades: ${list(m.screeningOnlySourceGrades)},`,
    `${i}betaSourceGrades: ${list(m.betaSourceGrades)},`,
    `${i}reliabilityTier: ${nullable(m.reliabilityTier)},`,
    `${i}improvementDirection: ${str(m.improvementDirection)},`,
    `${i}conditionKeys: ${list(m.conditionKeys)},`,
    `${i}availability: ${str(m.availability)},`,
    `${i}judgeAs: ${nullable(m.judgeAs)},`,
    `${i}storage: { collection: ${str(m.storage.collection)}, field: ${str(m.storage.field)} },`,
    `${i}range: ${range},`,
    '  },',
  ];
}

export function renderContracts({ metricCatalog, vocab, featureFlags }) {
  const t = (field) => typeName(METRIC_FIELD_ENUMS[field]);
  const out = ['export const CONTRACTS_VERSION = {'];
  for (const input of [metricCatalog, vocab, featureFlags]) {
    const { doc } = input;
    out.push(
      `  ${input.key}: { contract: ${str(doc.contract)}, version: ${doc.version}, revision: ${doc.revision}, sha256: ${str(input.sha12)} },`,
    );
  }
  out.push('} as const;', '', "export type VocabStatus = 'confirmed' | 'draft';");

  for (const [key, entry] of Object.entries(vocab.doc.enums)) {
    const type = typeName(key);
    const constName = pluralConstName(type);
    const status = entry.status === 'draft' ? `draft, confirmBy ${entry.confirmBy}` : 'confirmed';
    out.push(
      '',
      `/** vocab \`${key}\` (${status}). */`,
      ...constList(constName, entry.values),
      `export type ${type} = (typeof ${constName})[number];`,
    );
  }

  out.push('', '/** Status of every vocab block (V1-05 §13.2). */', 'export const VOCAB_STATUS = {');
  for (const [key, entry] of Object.entries(vocab.doc.enums)) out.push(`  ${key}: ${str(entry.status)},`);
  out.push(`  jointMotionPairs: ${str(vocab.doc.jointMotionPairs.status)},`);
  out.push('} as const satisfies Record<string, VocabStatus>;');

  const pairs = vocab.doc.jointMotionPairs.pairs;
  out.push(
    '',
    '/** Allowed joint/motion pairs. Empty while draft; do not check pairs until confirmed (ASM-P0-04). */',
    'export interface JointMotionPair {',
    `  readonly joint: ${typeName('joint')};`,
    `  readonly motions: ReadonlyArray<${typeName('motion')}>;`,
    '}',
    '',
    pairs.length === 0
      ? 'export const JOINT_MOTION_PAIRS: ReadonlyArray<JointMotionPair> = [];'
      : 'export const JOINT_MOTION_PAIRS: ReadonlyArray<JointMotionPair> = [',
    ...pairs.map((p) => `  { joint: ${str(p.joint)}, motions: [${p.motions.map(str).join(', ')}] },`),
    ...(pairs.length === 0 ? [] : ['];']),
  );

  const doc = metricCatalog.doc;
  out.push(
    '',
    '/** metricCode values in PRD appendix A.1 order. */',
    ...constList('METRIC_CODES', doc.metrics.map((m) => m.metricCode)),
    'export type MetricCode = (typeof METRIC_CODES)[number];',
    '',
    '/** Reserved or excluded codes (PRD appendix A.4). Reject on write. */',
    ...constList('EXCLUDED_METRIC_CODES', doc.excludedMetricCodes),
    '',
    'export interface MetricStorage {',
    '  readonly collection: string;',
    '  readonly field: string;',
    '}',
    '',
    'export interface MetricRange {',
    '  readonly min: number;',
    '  readonly minExclusive: boolean;',
    '  readonly max: number;',
    '  readonly appMin: number;',
    '}',
    '',
    'export interface MetricCatalogEntry {',
    '  readonly metricCode: MetricCode;',
    '  readonly nameKo: string;',
    `  readonly family: ${t('family')};`,
    `  readonly unit: ${t('unit')};`,
    '  readonly decimals: number;',
    `  readonly scale: ${t('scale')};`,
    `  readonly sideRule: ${t('sideRule')};`,
    `  readonly allowedSourceGrades: ReadonlyArray<${t('allowedSourceGrades')}>;`,
    `  readonly screeningOnlySourceGrades: ReadonlyArray<${t('screeningOnlySourceGrades')}>;`,
    `  readonly betaSourceGrades: ReadonlyArray<${t('betaSourceGrades')}>;`,
    `  readonly reliabilityTier: ${t('reliabilityTier')} | null;`,
    `  readonly improvementDirection: ${t('improvementDirection')};`,
    '  readonly conditionKeys: ReadonlyArray<string>;',
    `  readonly availability: ${t('availability')};`,
    '  readonly judgeAs: MetricCode | null;',
    '  readonly storage: MetricStorage;',
    '  readonly range: MetricRange | null;',
    '}',
    '',
    '/** metricCode -> metrics[] entry, in catalog order. */',
    'export const METRIC_CATALOG: Readonly<Record<MetricCode, MetricCatalogEntry>> = {',
  );
  for (const m of doc.metrics) out.push(...entryLiteral(m));
  out.push('};');

  // DF-027: contracts/feature-flags.v1.json for the AD-07 zod schema and editor.
  const flags = featureFlags.doc.flags;
  const list = (vs) => `[${vs.map(str).join(', ')}]`;
  out.push(
    '',
    '/** `appConfig/features` keys in contract order (ADR-010, V1-05 §4.17). */',
    ...constList('FEATURE_FLAG_KEYS', flags.map((f) => f.key)),
    'export type FeatureFlagKey = (typeof FEATURE_FLAG_KEYS)[number];',
    '',
    '/** Phase that may open a flag (PRD §12.3). `existing` is a member-app flag from before v1 (D4). */',
    `export type FeatureFlagPhase = ${FEATURE_FLAG_PHASES.map(str).join(' | ')};`,
    '',
    'export interface FeatureFlagDefinition {',
    '  readonly key: FeatureFlagKey;',
    '  /** Value when the document or the key is missing, or the stored value is not a boolean (AC-IA-02). */',
    '  readonly default: boolean;',
    '  readonly phase: FeatureFlagPhase;',
    '  readonly descriptionKo: string;',
    '  /** Collections whose Firestore rules check featureOn(key) (V1-05 §13.3). */',
    '  readonly ruleGatedCollections: ReadonlyArray<string>;',
    '}',
    '',
    '/** Flag definitions in contract order. */',
    'export const FEATURE_FLAGS: ReadonlyArray<FeatureFlagDefinition> = [',
    ...flags.flatMap((f) => [
      '  {',
      `    key: ${str(f.key)},`,
      `    default: ${f.default},`,
      `    phase: ${str(f.phase)},`,
      `    descriptionKo: ${str(f.descriptionKo)},`,
      `    ruleGatedCollections: ${list(f.ruleGatedCollections)},`,
      '  },',
    ]),
    '];',
  );
  return lines(out);
}

export const adminWebEmitters = Object.freeze({
  contracts: {
    id: 'adminWeb.contracts',
    path: `${ADMIN_WEB_DIR}/contracts.ts`,
    comment: '//',
    uses: ['metricCatalog', 'vocab', 'featureFlags'],
    render: renderContracts,
  },
});
