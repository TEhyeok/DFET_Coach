// DF-027 AC-DF-027.1: contracts/feature-flags.v1.json generates the eight keys, every default false, in four
// places (admin_web FEATURE_FLAGS, Dart FeatureFlagKey, Swift FeatureFlagKey, schemas/feature-flags.example.json).
// Reads the committed outputs; generate.test.mjs --check guarantees they match the generator.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, rmSync } from 'node:fs';
import path from 'node:path';

import { FEATURE_FLAG_PHASES } from '../emitters/common.mjs';
import { loadRules, scanText } from '../../lint/prohibited-terms.mjs';
import { REPO_ROOT, readContract } from './helpers.mjs';
import { makeRoot, removeRoot, runCli } from './harness.mjs';

// V1-05 §4.17 and §13.3, ADR-010 §3-1: three existing member-app flags, then the five v1 flags.
const EXPECTED_KEYS = ['gut', 'blood', 'insights', 'soapV2', 'bodyComposition', 'bodyAssessment', 'memberShare', 'lidarBeta'];
const EXPECTED_PHASES = ['existing', 'existing', 'existing', 'P1a', 'P1a', 'P1b', 'P2', 'P2'];

const doc = readContract('feature-flags.v1.json');
const read = (rel) => readFileSync(path.join(REPO_ROOT, rel), 'utf8');

test('AC-DF-027.1 contract lists the eight keys in V1-05 order, every default false', () => {
  assert.equal(doc.contract, 'feature-flags');
  assert.deepEqual(doc.flags.map((f) => f.key), EXPECTED_KEYS);
  assert.deepEqual(doc.flags.map((f) => f.phase), EXPECTED_PHASES);
  for (const f of doc.flags) {
    assert.equal(f.default, false, f.key);
    assert.ok(f.descriptionKo.length > 0, f.key);
  }
});

test('AC-DF-027.1 admin_web contracts.ts: FEATURE_FLAG_KEYS and FEATURE_FLAGS with default false', () => {
  const ts = read('admin_web/lib/generated/contracts.ts');
  const keysBlock = /export const FEATURE_FLAG_KEYS = \[\n([^\]]*)\] as const;/.exec(ts);
  assert.ok(keysBlock, 'FEATURE_FLAG_KEYS');
  assert.deepEqual([...keysBlock[1].matchAll(/'([^']+)'/g)].map((m) => m[1]), EXPECTED_KEYS);
  const flagsBlock = ts.slice(ts.indexOf('export const FEATURE_FLAGS:'));
  assert.deepEqual([...flagsBlock.matchAll(/^ {4}key: '([^']+)',$/gm)].map((m) => m[1]), EXPECTED_KEYS);
  const defaults = [...flagsBlock.matchAll(/^ {4}default: (\w+),$/gm)].map((m) => m[1]);
  assert.deepEqual(defaults, EXPECTED_KEYS.map(() => 'false'));
  for (const f of doc.flags) assert.ok(flagsBlock.includes(`    descriptionKo: '${f.descriptionKo}',`), f.key);
});

test('AC-DF-027.1 Dart feature_flags.g.dart: FeatureFlagKey with defaultValue false', () => {
  const dart = read('lib/contracts/generated/feature_flags.g.dart');
  const cases = [...dart.matchAll(/^ {2}(\w+)\('([^']+)', defaultValue: (\w+)\),$/gm)];
  assert.deepEqual(cases.map((m) => m[2]), EXPECTED_KEYS);
  assert.deepEqual(cases.map((m) => m[3]), EXPECTED_KEYS.map(() => 'false'));
});

test('AC-DF-027.1 Swift FeatureFlagKey.swift: eight cases, defaultValue false', () => {
  const swift = read('trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/FeatureFlagKey.swift');
  assert.ok(swift.includes('public enum FeatureFlagKey: String, Codable, CaseIterable, Sendable {'));
  assert.deepEqual([...swift.matchAll(/^ {2}case (\w+)$/gm)].map((m) => m[1]), EXPECTED_KEYS);
  const groups = [...swift.matchAll(/^ {4}case ([^:]+): return (true|false)$/gm)];
  assert.deepEqual(groups.map((m) => m[2]), ['false']);
  assert.deepEqual(groups[0][1].split(', ').map((c) => c.slice(1)), EXPECTED_KEYS);
  assert.ok(!/^import /m.test(swift), 'TrainerContracts stays free of imports (pure target)');
});

test('AC-DF-027.1 schemas/feature-flags.example.json is generated: eight keys, all false, contract order', () => {
  const text = read('schemas/feature-flags.example.json');
  const example = JSON.parse(text);
  assert.deepEqual(Object.keys(example), EXPECTED_KEYS);
  for (const key of EXPECTED_KEYS) assert.equal(example[key], false, key);
  assert.equal(text, `${JSON.stringify(example, null, 2)}\n`);
});

test('DF-027 descriptionKo labels pass the copy-lint common and trainer rule sets (PRD appendix C)', () => {
  // copy-lint TARGETS scans only metric-catalog and vocab among contracts/, so the admin labels are checked here.
  const compiled = loadRules(REPO_ROOT);
  for (const f of doc.flags) {
    const hits = scanText(f.descriptionKo, compiled, { ruleSets: ['common', 'trainer'], key: `flags.${f.key}.descriptionKo` });
    assert.deepEqual(hits.map((h) => `${h.ruleId} ${h.match}`), [], f.key);
  }
});

test('DF-027 FEATURE_FLAG_PHASES equals the meta-schema phase enum', () => {
  const meta = JSON.parse(read('schemas/contracts-meta.schema.json'));
  assert.deepEqual(meta.$defs.featureFlag.properties.phase.enum, [...FEATURE_FLAG_PHASES]);
  assert.deepEqual(meta.$defs.featureFlag.properties.default, { description: meta.$defs.featureFlag.properties.default.description, const: false });
});

test('DF-027 a missing feature-flags.v1.json skips only the flag outputs (and admin_web contracts.ts)', () => {
  const root = makeRoot();
  try {
    rmSync(path.join(root, 'contracts/feature-flags.v1.json'));
    const r = runCli(['--root', root]);
    assert.equal(r.code, 0, r.stderr);
    assert.match(r.stderr, /warning: contracts\/feature-flags\.v1\.json not found; skipping its outputs/);
    for (const rel of [
      'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/FeatureFlagKey.swift',
      'lib/contracts/generated/feature_flags.g.dart',
      'schemas/feature-flags.example.json',
      'admin_web/lib/generated/contracts.ts',
    ]) {
      assert.ok(!existsSync(path.join(root, rel)), rel);
    }
    assert.ok(existsSync(path.join(root, 'lib/contracts/generated/vocab.g.dart')));
  } finally {
    removeRoot(root);
  }
});
