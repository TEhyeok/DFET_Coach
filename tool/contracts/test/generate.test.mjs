// DF-004 generator tests: TC-DF004-01 (determinism), TC-DF004-02 (--check drift),
// TC-DF004-03 (meta-schema and cross checks), AC-DF-004.1 (four output locations),
// AC-DF-004.5 (header line). Every run works on a temp copy of the repository inputs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import { GENERATED_DIRS } from '../generate.mjs';
import { REPO_ROOT } from './helpers.mjs';
import { applyPatch, makeRoot, readJson, removeRoot, runCli, writeJson } from './harness.mjs';

const FIXTURES = path.join(REPO_ROOT, 'tool', 'contracts', 'test', 'fixtures');

// AC-DF-004.1: the files the generator owns in its directories for the v1 inputs (ten from DF-004, two
// from DF-010, two from DF-027). DF-027 also writes schemas/feature-flags.example.json, outside those
// directories (see EXTRA_OUTPUTS).
const EXPECTED_OUTPUTS = [
  'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/MetricCatalog.swift',
  'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/Vocab.swift',
  'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/ContractsVersion.swift',
  'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/ProhibitedTerms.swift',
  'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/FeatureFlagKey.swift',
  'lib/contracts/generated/metric_catalog.g.dart',
  'lib/contracts/generated/vocab.g.dart',
  'lib/contracts/generated/contracts_version.g.dart',
  'lib/contracts/generated/feature_flags.g.dart',
  'functions/src/shared/generated/contracts.js',
  'functions/src/shared/generated/json/metric-catalog.v1.json',
  'functions/src/shared/generated/json/vocab.v1.json',
  'functions/src/shared/generated/json/prohibited-terms.v1.json',
  'admin_web/lib/generated/contracts.ts',
].sort();

// Generated files outside GENERATED_DIRS (the rest of their directory is hand-written).
const EXTRA_OUTPUTS = ['schemas/feature-flags.example.json'];
const OUTPUT_COUNT = EXPECTED_OUTPUTS.length + EXTRA_OUTPUTS.length;

// Which inputs each output is generated from (header `from ...`).
const SOURCES = {
  'MetricCatalog.swift': ['metric-catalog.v1.json'],
  'Vocab.swift': ['vocab.v1.json'],
  'ContractsVersion.swift': ['metric-catalog.v1.json', 'vocab.v1.json'],
  'ProhibitedTerms.swift': ['prohibited-terms.v1.json'],
  'FeatureFlagKey.swift': ['feature-flags.v1.json'],
  'feature_flags.g.dart': ['feature-flags.v1.json'],
  'metric_catalog.g.dart': ['metric-catalog.v1.json'],
  'vocab.g.dart': ['vocab.v1.json'],
  'contracts_version.g.dart': ['metric-catalog.v1.json', 'vocab.v1.json'],
  'contracts.js': ['metric-catalog.v1.json', 'vocab.v1.json'],
  'contracts.ts': ['metric-catalog.v1.json', 'vocab.v1.json', 'feature-flags.v1.json'],
};

function listGenerated(root) {
  const found = [];
  for (const dir of GENERATED_DIRS) {
    const abs = path.join(root, dir);
    if (!existsSync(abs)) continue;
    for (const ent of readdirSync(abs, { withFileTypes: true, recursive: true })) {
      if (ent.isFile()) found.push(path.relative(root, path.join(ent.parentPath, ent.name)).split(path.sep).join('/'));
    }
  }
  return found.sort();
}

function snapshot(root) {
  return new Map([...listGenerated(root), ...EXTRA_OUTPUTS].map((rel) => [rel, readFileSync(path.join(root, rel))]));
}

test('AC-DF-004.1 generate writes the four consumer locations', () => {
  const root = makeRoot();
  try {
    const r = runCli(['--root', root]);
    assert.equal(r.code, 0, r.stderr);
    assert.deepEqual(listGenerated(root), EXPECTED_OUTPUTS);
    for (const rel of EXTRA_OUTPUTS) assert.ok(existsSync(path.join(root, rel)), rel);
  } finally {
    removeRoot(root);
  }
});

test('TC-DF004-01 second run changes 0 bytes (deterministic output)', () => {
  const root = makeRoot();
  try {
    assert.equal(runCli(['--root', root]).code, 0);
    const first = snapshot(root);
    const r = runCli(['--root', root]);
    assert.equal(r.code, 0, r.stderr);
    assert.match(r.stdout, new RegExp(`${OUTPUT_COUNT} generated files, 0 changed`));
    const second = snapshot(root);
    assert.deepEqual([...second.keys()], [...first.keys()]);
    for (const [rel, bytes] of first) assert.ok(bytes.equals(second.get(rel)), `${rel} changed on the second run`);

    // A fresh root gives the same bytes too (no timestamps, paths or randomness in the output).
    const other = makeRoot();
    try {
      assert.equal(runCli(['--root', other]).code, 0);
      for (const [rel, bytes] of first) assert.ok(bytes.equals(readFileSync(path.join(other, rel))), `${rel} differs between roots`);
    } finally {
      removeRoot(other);
    }
  } finally {
    removeRoot(root);
  }
});

test('TC-DF004-01 committed generated files are up to date (--check on this checkout)', () => {
  const r = runCli(['--check']);
  assert.equal(r.code, 0, r.stderr);
  assert.match(r.stdout, new RegExp(`${OUTPUT_COUNT} generated files are up to date`));
});

test('AC-DF-004.5 every generated file starts with the GENERATED header and input hash', () => {
  const root = makeRoot();
  try {
    assert.equal(runCli(['--root', root]).code, 0);
    const inputBytes = (f) => readFileSync(path.join(root, 'contracts', f));
    for (const rel of listGenerated(root)) {
      const text = readFileSync(path.join(root, rel), 'utf8');
      assert.ok(!text.includes('\r'), `${rel} has CR`);
      assert.ok(text.endsWith('\n') && !text.endsWith('\n\n'), `${rel} must end with exactly one LF`);
      if (rel.endsWith('.json')) {
        // JSON cannot carry a comment: the Functions copy is byte-identical to its input instead.
        assert.ok(inputBytes(path.basename(rel)).equals(readFileSync(path.join(root, rel))), `${rel} is not a verbatim copy`);
        continue;
      }
      const sources = SOURCES[path.basename(rel)];
      const hash = createHash('sha256').update(Buffer.concat(sources.map(inputBytes))).digest('hex').slice(0, 12);
      const from = sources.map((f) => `contracts/${f}`).join(', ');
      const first = text.split('\n', 1)[0];
      assert.equal(first, `// GENERATED by tool/contracts/generate.mjs from ${from} — DO NOT EDIT. sha256:${hash}`, rel);
    }
  } finally {
    removeRoot(root);
  }
});

test('AC-DF-004.5 header hash follows the input bytes', () => {
  const root = makeRoot();
  try {
    assert.equal(runCli(['--root', root]).code, 0);
    const rel = 'lib/contracts/generated/vocab.g.dart';
    const before = readFileSync(path.join(root, rel), 'utf8').split('\n', 1)[0];
    const vocab = readJson(root, 'contracts/vocab.v1.json');
    vocab.revision += 1;
    writeJson(root, 'contracts/vocab.v1.json', vocab);
    assert.equal(runCli(['--root', root, '--check']).code, 1, 'input change must be reported as drift');
    assert.equal(runCli(['--root', root]).code, 0);
    const after = readFileSync(path.join(root, rel), 'utf8').split('\n', 1)[0];
    assert.notEqual(after, before);
  } finally {
    removeRoot(root);
  }
});

test('AC-DF-004.2 / TC-DF004-02 a hand edit in vocab.g.dart makes --check exit 1 and name the file', () => {
  const root = makeRoot();
  try {
    assert.equal(runCli(['--root', root]).code, 0);
    assert.equal(runCli(['--root', root, '--check']).code, 0);
    const rel = 'lib/contracts/generated/vocab.g.dart';
    const abs = path.join(root, rel);
    const text = readFileSync(abs, 'utf8');
    assert.ok(text.includes("  tape('tape'),"));
    writeFileSync(abs, text.replace("  tape('tape'),", "  tape('Tape'),"));

    const r = runCli(['--root', root, '--check']);
    assert.equal(r.code, 1);
    assert.match(r.stderr, /1 generated file\(s\) differ/);
    assert.match(r.stderr, /modified\s+lib\/contracts\/generated\/vocab\.g\.dart/);
    // --check never writes.
    assert.equal(readFileSync(abs, 'utf8'), text.replace("  tape('tape'),", "  tape('Tape'),"));
  } finally {
    removeRoot(root);
  }
});

test('TC-DF004-02 a single flipped byte in any generated file is drift', () => {
  const root = makeRoot();
  try {
    assert.equal(runCli(['--root', root]).code, 0);
    const rel = 'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/MetricCatalog.swift';
    const abs = path.join(root, rel);
    const bytes = readFileSync(abs);
    bytes[bytes.length - 2] ^= 0x01;
    writeFileSync(abs, bytes);
    const r = runCli(['--root', root, '--check']);
    assert.equal(r.code, 1);
    assert.ok(r.stderr.includes(rel));
  } finally {
    removeRoot(root);
  }
});

test('TC-DF004-02 --check reports missing and unexpected files; generate repairs them', () => {
  const root = makeRoot();
  try {
    assert.equal(runCli(['--root', root]).code, 0);
    rmSync(path.join(root, 'admin_web/lib/generated/contracts.ts'));
    writeFileSync(path.join(root, 'functions/src/shared/generated/json/old.v0.json'), '{}\n');
    const r = runCli(['--root', root, '--check']);
    assert.equal(r.code, 1);
    assert.match(r.stderr, /missing\s+admin_web\/lib\/generated\/contracts\.ts/);
    assert.match(r.stderr, /unexpected\s+functions\/src\/shared\/generated\/json\/old\.v0\.json/);

    assert.equal(runCli(['--root', root]).code, 0);
    assert.equal(runCli(['--root', root, '--check']).code, 0);
    assert.deepEqual(listGenerated(root), EXPECTED_OUTPUTS);
  } finally {
    removeRoot(root);
  }
});

const badFixtures = readdirSync(FIXTURES).filter((f) => /^bad-.*\.json$/.test(f)).sort();

test('bad-* fixtures exist for every SPRINT_01 004-4 rejection case', () => {
  for (const name of [
    'bad-missing-field.json',
    'bad-duplicate-metric-code.json',
    'bad-excluded-code.json',
    'bad-unknown-source-grade.json',
  ]) {
    assert.ok(badFixtures.includes(name), name);
  }
});

for (const name of badFixtures) {
  const fixture = JSON.parse(readFileSync(path.join(FIXTURES, name), 'utf8'));
  for (const mode of [['--check'], []]) {
    test(`AC-DF-004.3 / TC-DF004-03 ${name} ${mode.join(' ') || '(write)'} exits 1 with a JSON pointer message: ${fixture.description}`, () => {
      const root = makeRoot();
      try {
        const rel = `contracts/${fixture.file}`;
        writeJson(root, rel, applyPatch(readJson(root, rel), fixture.patch));
        const r = runCli(['--root', root, ...mode]);
        assert.equal(r.code, 1, r.stdout + r.stderr);
        for (const expected of fixture.expect) assert.ok(r.stderr.includes(expected), `missing "${expected}" in:\n${r.stderr}`);
        // Validation runs before anything is rendered or written.
        assert.deepEqual(listGenerated(root), []);
      } finally {
        removeRoot(root);
      }
    });
  }
}

test('AC-DF-004.3 meta-schema errors are reported before cross checks', () => {
  const root = makeRoot();
  try {
    const rel = 'contracts/metric-catalog.v1.json';
    const doc = readJson(root, rel);
    delete doc.metrics[2].family; // schema error
    doc.metrics[5].metricCode = doc.metrics[4].metricCode; // cross-check error
    writeJson(root, rel, doc);
    const r = runCli(['--root', root, '--check']);
    assert.equal(r.code, 1);
    assert.match(r.stderr, /#\/metrics\/2: must have required property 'family'/);
    assert.doesNotMatch(r.stderr, /duplicate metricCode/);
  } finally {
    removeRoot(root);
  }
});

test('invalid JSON input exits 1 without writing', () => {
  const root = makeRoot();
  try {
    writeFileSync(path.join(root, 'contracts/vocab.v1.json'), '{ "contract": "vocab", ');
    const r = runCli(['--root', root, '--check']);
    assert.equal(r.code, 1);
    assert.match(r.stderr, /contracts\/vocab\.v1\.json: invalid JSON/);
  } finally {
    removeRoot(root);
  }
});

test('a missing input is skipped with a warning, together with the outputs that need it', () => {
  const root = makeRoot();
  try {
    rmSync(path.join(root, 'contracts/metric-catalog.v1.json'));
    const r = runCli(['--root', root]);
    assert.equal(r.code, 0, r.stderr);
    assert.match(r.stderr, /warning: contracts\/metric-catalog\.v1\.json not found; skipping its outputs/);
    const files = listGenerated(root);
    assert.ok(files.includes('lib/contracts/generated/vocab.g.dart'));
    assert.ok(files.includes('lib/contracts/generated/contracts_version.g.dart'), 'version file renders from the inputs present');
    assert.ok(!files.includes('lib/contracts/generated/metric_catalog.g.dart'));
    assert.ok(!files.includes('admin_web/lib/generated/contracts.ts'), 'needs metric-catalog, vocab and feature-flags');
    const version = readFileSync(path.join(root, 'lib/contracts/generated/contracts_version.g.dart'), 'utf8');
    assert.match(version.split('\n', 1)[0], /from contracts\/vocab\.v1\.json — DO NOT EDIT/);
  } finally {
    removeRoot(root);
  }
});

test('unknown arguments exit 2', () => {
  const r = runCli(['--chek']);
  assert.equal(r.code, 2);
  assert.match(r.stderr, /unknown argument --chek/);
});

test('--root without a directory exits 2 instead of using the current directory', () => {
  for (const args of [['--root'], ['--root', ''], ['--root', '--check']]) {
    const r = runCli(args);
    assert.equal(r.code, 2, JSON.stringify(args));
    assert.match(r.stderr, /--root needs a directory/);
  }
});
