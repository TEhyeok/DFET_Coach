// DF-004 emitter tests: TC-DF004-04 (Swift `none` escaping, Dart fromWire null) on the real contracts,
// and per-emitter snapshots on a small synthetic contract that exercises escaping, drafts and pairs.
// Update snapshots after an intended emitter change with: UPDATE_SNAPSHOTS=1 node --test 'tool/contracts/test/**/*.test.mjs'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import { loadInputs, renderOutputs, validateInputs, DEFAULT_ROOT } from '../generate.mjs';
import { pluralConstName, screamingSnake, typeName } from '../emitters/common.mjs';
import { swiftCase } from '../emitters/swift.mjs';
import { dartIdent } from '../emitters/dart.mjs';
import { REPO_ROOT } from './helpers.mjs';

const SNAPSHOTS = path.join(REPO_ROOT, 'tool', 'contracts', 'test', 'snapshots');

function realOutputs() {
  const { loaded } = loadInputs(DEFAULT_ROOT);
  assert.deepEqual(validateInputs(DEFAULT_ROOT, loaded), []);
  return renderOutputs(loaded).outputs;
}

const real = realOutputs();
const get = (suffix) => [...real].find(([rel]) => rel.endsWith(suffix))[1];

test('TC-DF004-04 Swift escapes `none` and keeps its raw value', () => {
  const swift = get('Generated/Vocab.swift');
  assert.ok(swift.includes('  case `none` = "none"'));
  assert.match(swift, /public enum SourceGrade: String, Codable, CaseIterable, Sendable \{\n {2}case tape\n {2}case device\n/);
  const catalog = get('Generated/MetricCatalog.swift');
  assert.ok(catalog.includes('sideRule: .`none`,'));
  assert.ok(catalog.includes('public static func entry(for code: MetricCode) -> MetricCatalogEntry {'));
  assert.ok(!/^import /m.test(swift + catalog), 'TrainerContracts stays free of imports (pure target)');
});

test("TC-DF004-04 Dart fromWire returns null for unknown values (fromWire('unknown') == null)", () => {
  const dart = get('generated/vocab.g.dart');
  const block = dart.slice(dart.indexOf('enum SourceGrade {'), dart.indexOf('\n}\n', dart.indexOf('enum SourceGrade {')));
  assert.match(block, /^ {2}tape\('tape'\),$/m);
  assert.ok(block.includes('  static SourceGrade? fromWire(String? value) {'));
  assert.ok(block.includes('    for (final candidate in SourceGrade.values) {\n      if (candidate.wire == value) return candidate;\n    }\n    return null;'));
  // Mirror of the generated lookup: only exact wire strings resolve; 'unknown' and null give null.
  const wires = [...block.matchAll(/^ {2}\w+\('([^']+)'\),$/gm)].map((m) => m[1]);
  const fromWire = (v) => (wires.includes(v) ? v : null);
  assert.equal(fromWire('unknown'), null);
  assert.equal(fromWire(null), null);
  assert.equal(fromWire('Tape'), null);
  assert.equal(fromWire('tape'), 'tape');
});

test('Functions output is CommonJS with use strict and a frozen export', () => {
  const js = get('generated/contracts.js');
  assert.equal(js.split('\n')[1], "'use strict';");
  assert.match(js, /module\.exports = Object\.freeze\(\{\n {2}CONTRACTS_VERSION,\n {2}METRIC_CODES,/);
  assert.ok(js.includes("require('./json/metric-catalog.v1.json')"));
});

test('admin_web output exposes as-const lists and derived types', () => {
  const ts = get('generated/contracts.ts');
  assert.ok(ts.includes("export const SOURCE_GRADES = [\n  'tape',"));
  assert.ok(ts.includes('export type SourceGrade = (typeof SOURCE_GRADES)[number];'));
  assert.ok(ts.includes('export const METRIC_UNITS = ['), 'unit maps to MetricUnit (avoids Foundation.Unit)');
  assert.ok(ts.includes('export const METRIC_CATALOG: Readonly<Record<MetricCode, MetricCatalogEntry>> = {'));
});

test('output order follows input order (no sorting)', () => {
  const ts = get('generated/contracts.ts');
  const { loaded } = loadInputs(DEFAULT_ROOT);
  const codes = loaded.metricCatalog.doc.metrics.map((m) => m.metricCode);
  const positions = codes.map((c) => ts.indexOf(`\n  ${c}: {`));
  assert.ok(positions.every((p) => p > 0));
  assert.deepEqual(positions, [...positions].sort((a, b) => a - b));
  const enumNames = Object.keys(loaded.vocab.doc.enums).map(typeName);
  const dart = get('generated/vocab.g.dart');
  const enumPositions = enumNames.map((n) => dart.indexOf(`\nenum ${n} {`));
  assert.deepEqual(enumPositions, [...enumPositions].sort((a, b) => a - b));
});

test('naming helpers', () => {
  assert.equal(typeName('sourceGrade'), 'SourceGrade');
  assert.equal(typeName('unit'), 'MetricUnit');
  assert.equal(screamingSnake('TimeOfDayBand'), 'TIME_OF_DAY_BAND');
  assert.equal(pluralConstName('SourceGrade'), 'SOURCE_GRADES');
  assert.equal(pluralConstName('SoapStatus'), 'SOAP_STATUSES');
  assert.equal(pluralConstName('Availability'), 'AVAILABILITIES');
  assert.equal(pluralConstName('Family'), 'FAMILIES');
  assert.equal(pluralConstName('CircumferenceProtocolId'), 'CIRCUMFERENCE_PROTOCOL_IDS');
  assert.equal(swiftCase('none'), '`none`');
  assert.equal(swiftCase('default'), '`default`');
  assert.equal(swiftCase('tape'), 'tape');
  assert.equal(dartIdent('default'), 'defaultValue');
  assert.equal(dartIdent('values'), 'valuesValue');
  assert.equal(dartIdent('none'), 'none');
});

// ---------------------------------------------------------------------------------------------
// Snapshots on a synthetic contract (not schema-validated: it only needs the enums the emitters read).

const enumOf = (values, extra = {}) => ({ status: 'confirmed', values, ...extra });
const MINI_VOCAB = {
  contract: 'vocab',
  version: 1,
  revision: 7,
  source: 'synthetic test contract',
  enums: {
    sourceGrade: enumOf(['tape', 'photoAuto', 'derived']),
    reliabilityTier: enumOf(['tier1', 'reference']),
    improvementDirection: enumOf(['higherIsBetter', 'none']),
    family: enumOf(['posture', 'bodyComposition']),
    sideRule: enumOf(['none', 'leftRight']),
    availability: enumOf(['v1', 'v2']),
    scale: enumOf(['ratio']),
    unit: enumOf(['deg', 'kg']),
    keywordish: enumOf(['default', 'required', 'values', 'in', 'self'], { status: 'draft', confirmBy: 'DF-999' }),
    joint: enumOf(['knee'], { status: 'draft', confirmBy: 'DF-916' }),
    motion: enumOf(['flexion', 'extension'], { status: 'draft', confirmBy: 'DF-916' }),
  },
  jointMotionPairs: { status: 'draft', confirmBy: 'DF-916', pairs: [{ joint: 'knee', motions: ['flexion', 'extension'] }] },
};
const MINI_CATALOG = {
  contract: 'metric-catalog',
  version: 1,
  revision: 3,
  source: 'synthetic test contract',
  metrics: [
    {
      metricCode: 'kneeAngle',
      nameKo: '무릎 "각도" \'인용\' $x \\ 역슬래시',
      family: 'posture',
      unit: 'deg',
      decimals: 1,
      scale: 'ratio',
      sideRule: 'leftRight',
      allowedSourceGrades: ['tape', 'photoAuto'],
      screeningOnlySourceGrades: ['photoAuto'],
      betaSourceGrades: [],
      reliabilityTier: 'tier1',
      improvementDirection: 'none',
      conditionKeys: ['protocolVersion', 'device.model'],
      availability: 'v1',
      judgeAs: null,
      storage: { collection: 'soap_notes', field: 'objective.metrics' },
      range: null,
    },
    {
      metricCode: 'massIndex',
      nameKo: '지수',
      family: 'bodyComposition',
      unit: 'kg',
      decimals: 0,
      scale: 'ratio',
      sideRule: 'none',
      allowedSourceGrades: ['derived'],
      screeningOnlySourceGrades: [],
      betaSourceGrades: [],
      reliabilityTier: null,
      improvementDirection: 'higherIsBetter',
      conditionKeys: ['fasting'],
      availability: 'v2',
      judgeAs: 'kneeAngle',
      storage: { collection: 'bodyCompositionRecords', field: 'derived.massIndex' },
      range: { min: 0, minExclusive: true, max: 200.5, appMin: 0.1 },
    },
  ],
  excludedMetricCodes: ['oldCode'],
};

// Not schema-valid on purpose: one default true exercises the Swift `defaultValue` grouping, and `in`
// exercises escaping (Swift backticks, Dart `inValue`).
const MINI_FLAGS = {
  contract: 'feature-flags',
  version: 1,
  revision: 2,
  source: 'synthetic test contract',
  flags: [
    { key: 'gut', default: false, phase: 'existing', descriptionKo: '장 \'인용\' $x', ruleGatedCollections: [] },
    { key: 'in', default: true, phase: 'P3', descriptionKo: '예약어 키', ruleGatedCollections: ['soap_notes', 'circumferenceMeasurements(tape)'] },
    { key: 'soapV2', default: false, phase: 'P1a', descriptionKo: 'SOAP', ruleGatedCollections: ['soap_notes'] },
  ],
};

function loadedFrom(key, file, doc) {
  const text = `${JSON.stringify(doc, null, 2)}\n`;
  const buf = Buffer.from(text, 'utf8');
  const hash = createHash('sha256').update(buf).digest('hex');
  return { key, file, doc, text, buf, sha256: hash, sha12: hash.slice(0, 12) };
}

const miniOutputs = renderOutputs({
  metricCatalog: loadedFrom('metricCatalog', 'metric-catalog.v1.json', MINI_CATALOG),
  vocab: loadedFrom('vocab', 'vocab.v1.json', MINI_VOCAB),
  featureFlags: loadedFrom('featureFlags', 'feature-flags.v1.json', MINI_FLAGS),
}).outputs;

for (const [rel, content] of miniOutputs) {
  if (rel.endsWith('.json')) continue; // verbatim copies, covered in generate.test.mjs
  const snap = path.join(SNAPSHOTS, `${path.basename(rel)}.snap`);
  test(`snapshot ${path.basename(rel)} (synthetic contract)`, () => {
    if (process.env.UPDATE_SNAPSHOTS === '1' || !existsSync(snap)) {
      mkdirSync(SNAPSHOTS, { recursive: true });
      writeFileSync(snap, content);
      if (process.env.UPDATE_SNAPSHOTS !== '1') assert.fail(`wrote missing snapshot ${snap}; review and commit it`);
    }
    assert.equal(content, readFileSync(snap, 'utf8'));
  });
}

test('synthetic contract: escaping per language', () => {
  const out = (suffix) => [...miniOutputs].find(([rel]) => rel.endsWith(suffix))[1];
  const swiftVocab = out('Vocab.swift');
  assert.ok(swiftVocab.includes('  case `default` = "default"'));
  assert.ok(swiftVocab.includes('  case `in` = "in"'));
  assert.ok(swiftVocab.includes('  case `self` = "self"'));
  assert.ok(swiftVocab.includes('  case required\n'));
  const dartVocab = out('vocab.g.dart');
  assert.ok(dartVocab.includes("  defaultValue('default'),"));
  assert.ok(dartVocab.includes("  valuesValue('values'),"));
  assert.ok(dartVocab.includes("  inValue('in'),"));
  // Strings: Swift escapes " and \; Dart escapes ' \ and $; TypeScript escapes ' and \ only.
  assert.ok(out('MetricCatalog.swift').includes('nameKo: "무릎 \\"각도\\" \'인용\' $x \\\\ 역슬래시",'));
  assert.ok(out('metric_catalog.g.dart').includes("nameKo: '무릎 \"각도\" \\'인용\\' \\$x \\\\ 역슬래시',"));
  assert.ok(out('contracts.ts').includes("nameKo: '무릎 \"각도\" \\'인용\\' $x \\\\ 역슬래시',"));
});

test('synthetic contract: feature flag keys per language (DF-027)', () => {
  const out = (suffix) => [...miniOutputs].find(([rel]) => rel.endsWith(suffix))[1];
  const swift = out('FeatureFlagKey.swift');
  assert.ok(swift.includes('  case `in` = "in"\n'));
  assert.ok(swift.includes('    case .`in`: return true\n    case .gut, .soapV2: return false\n'));
  const dart = out('feature_flags.g.dart');
  assert.ok(dart.includes("  inValue('in', defaultValue: true),"));
  assert.ok(dart.includes('  static FeatureFlagKey? fromWire(String? value) {'));
  const ts = out('contracts.ts');
  assert.ok(ts.includes("export const FEATURE_FLAG_KEYS = [\n  'gut',\n  'in',\n  'soapV2',\n] as const;"));
  assert.ok(ts.includes("    descriptionKo: '장 \\'인용\\' $x',"));
  assert.ok(ts.includes("    ruleGatedCollections: ['soap_notes', 'circumferenceMeasurements(tape)'],"));
  assert.equal(out('feature-flags.example.json'), '{\n  "gut": false,\n  "in": true,\n  "soapV2": false\n}\n');
});
