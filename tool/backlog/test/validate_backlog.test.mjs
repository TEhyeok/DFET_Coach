// TC-DF002-03 validate_backlog.mjs 검출 테스트(node:test, Node 22 내장 모듈만).
// 실제 issues.json을 임시 폴더에 issues.json이라는 같은 이름으로 복사하고 한 곳만 바꿔
// 검증기가 그 오류 하나를 찾아 exit 1을 내는지 본다. 네트워크에 접근하지 않는다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..', '..');
const validator = join(root, 'tool/backlog/validate_backlog.mjs');
const prd = join(root, 'docs/PRD_V1.md');
const original = JSON.parse(readFileSync(join(root, 'tool/backlog/issues.json'), 'utf8'));

function run(args) {
  const r = spawnSync(process.execPath, [validator, ...args], { cwd: root, encoding: 'utf8' });
  return { code: r.status, out: r.stdout, err: r.stderr };
}

// mutate(doc)로 바꾼 사본을 <tmp>/issues.json에 써서 검증기를 돌린다.
function validateMutated(mutate) {
  const doc = structuredClone(original);
  mutate(doc);
  const dir = mkdtempSync(join(tmpdir(), 'dfet-validate-'));
  try {
    const file = join(dir, 'issues.json');
    writeFileSync(file, JSON.stringify(doc, null, 2));
    return run(['--prd', prd, file]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const item = (doc, key) => {
  const it = doc.issues.find((x) => x.key === key);
  assert.ok(it, `${key} exists in issues.json`);
  return it;
};

test('AC-DF-002.3 current issues.json passes with the CI arguments', () => {
  const r = run(['--prd', 'docs/PRD_V1.md', 'tool/backlog/issues.json']);
  assert.equal(r.code, 0, r.err);
  assert.match(r.out, /^OK: \d+ items, \d+ labels, \d+ milestones, PRD PRD_V1\.md/);
});

test('AC-DF-002.3 validator runs with no arguments (default PRD and issues.json)', () => {
  const r = run([]);
  assert.equal(r.code, 0, r.err);
});

test('AC-DF-002.3 unchanged copy passes (control for the mutation tests)', () => {
  const r = validateMutated(() => {});
  assert.equal(r.code, 0, r.err);
});

test('AC-DF-002.4 unknown trace F-SOAP-99 fails with the file/key message', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').trace.push('F-SOAP-99'));
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 trace F-SOAP-99 not found in PRD$/m);
  assert.match(r.err, /FAIL: 1 error\(s\)/);
});

// AC-DF-002.3이 나열한 trace 접두 14종. 실제 PRD ID는 통과하고, 없는 ID는 접두마다 하나씩 잡힌다.
const PREFIX_REAL = ['F-SOAP-01', 'AC-SOAP-01.1', 'C-01', 'NFR-01', 'TR-01', 'MB-01', 'AD-01', 'R-01', 'S-01', 'MIG-01', 'G-01', 'M-01', 'Q-01', 'AS-01'];
const PREFIX_FAKE = ['F-SOAP-99', 'AC-SOAP-99.9', 'C-99', 'NFR-99', 'TR-99', 'MB-99', 'AD-99', 'R-99', 'S-99', 'MIG-99', 'G-99', 'M-99', 'Q-99', 'AS-99'];

test('AC-DF-002.3 real IDs for every trace prefix are found in the PRD', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').trace.push(...PREFIX_REAL));
  assert.equal(r.code, 0, r.err);
});

test('AC-DF-002.3 missing IDs for every trace prefix are reported one by one', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').trace.push(...PREFIX_FAKE));
  assert.equal(r.code, 1);
  for (const id of PREFIX_FAKE) {
    assert.match(r.err, new RegExp(`^issues\\.json: DF-002 trace ${id.replace('.', '\\.')} not found in PRD$`, 'm'));
  }
  assert.match(r.err, new RegExp(`FAIL: ${PREFIX_FAKE.length} error\\(s\\)`));
});

test('AC-DF-002.3 range token checks both ends (R-01~R-99 fails on R-99 only)', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').trace.push('R-01~R-99'));
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 trace R-99 not found in PRD$/m);
  assert.doesNotMatch(r.err, /trace R-01 not found/);
});

test('AC-DF-002.3 unknown PRD section (§99.9) fails', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').trace.push('§99.9'));
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 trace §99\.9 section not found in PRD$/m);
});

test('AC-DF-002.3 development IDs (AC-DF-*) are not looked up in the PRD', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').trace.push('AC-DF-002.9'));
  assert.equal(r.code, 0, r.err);
});

test('AC-DF-002.3 duplicate DF key fails', () => {
  const r = validateMutated((doc) => doc.issues.push(structuredClone(item(doc, 'DF-002'))));
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 duplicate key$/m);
});

test('AC-DF-002.3 label missing from labels.json fails', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').labels.push('area/does-not-exist'));
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 label area\/does-not-exist not in labels\.json$/m);
});

test('AC-DF-002.3 milestone missing from milestones.json fails', () => {
  const r = validateMutated((doc) => { item(doc, 'DF-002').milestone = 'P9 없는 마일스톤'; });
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 milestone P9 없는 마일스톤 not in milestones\.json$/m);
});

test('AC-DF-002.3 unknown epic reference fails', () => {
  const r = validateMutated((doc) => { item(doc, 'DF-002').epic = 'EP-99'; });
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 epic EP-99 not found$/m);
});

test('AC-DF-002.3 dependency on a missing key fails', () => {
  const r = validateMutated((doc) => item(doc, 'DF-002').deps.push('DF-998'));
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 dependency DF-998 not found$/m);
});

test('AC-DF-002.3 dependency cycle DF-001 -> DF-002 -> DF-001 fails', () => {
  const r = validateMutated((doc) => {
    item(doc, 'DF-001').deps.push('DF-002');
    item(doc, 'DF-002').deps.push('DF-001');
  });
  assert.equal(r.code, 1);
  assert.match(r.err, /dependency cycle .*DF-00[12] -> DF-00[12] -> DF-00[12]/);
});

test('AC-DF-002.3 cycle through cardDeps is also detected', () => {
  const r = validateMutated((doc) => {
    item(doc, 'DF-003').cardDeps.push('DF-004');   // DF-004는 색인상 DF-003에 의존한다
  });
  assert.equal(r.code, 1);
  assert.match(r.err, /dependency cycle/);
});

test('AC-DF-002.3 schema: missing required key fails', () => {
  const r = validateMutated((doc) => { delete item(doc, 'DF-002').sourceDoc; });
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 missing required sourceDoc$/m);
});

test('AC-DF-002.3 schema: wrong type and enum value fail', () => {
  const r = validateMutated((doc) => {
    const it = item(doc, 'DF-002');
    it.points = '2';
    it.kind = 'feature';
  });
  assert.equal(r.code, 1);
  assert.match(r.err, /^issues\.json: DF-002 points type$/m);
  assert.match(r.err, /^issues\.json: DF-002 kind not in enum: feature$/m);
});
