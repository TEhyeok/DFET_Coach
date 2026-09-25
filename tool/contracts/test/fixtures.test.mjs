// TC-DF005-01~04: SOAP cross-client fixtures (contracts/fixtures/**) follow the P0 DF-005 fixture contract
// (docs/v1/backlog/P0.md#fixture-contract, copied to contracts/fixtures/README.md). Node 22 built-ins only.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

import { REPO_ROOT, readContract } from './helpers.mjs';

const FIXTURES_DIR = path.join(REPO_ROOT, 'contracts', 'fixtures');

// ---------------------------------------------------------------------------------------------
// Expected values, copied by hand from the contract's file table (rule 4). Do not derive them
// from the fixtures: the point is that the table and the files are checked against each other.
// ---------------------------------------------------------------------------------------------

const V2_INPUTS = {
  finalized_no_metrics: { metricCount: 0 },
  draft_rom_mmt_pain: { metricCount: 2 },
  pending_member_draft: { metricCount: 0 },
  refs_snapshots_pending_policy: { metricCount: 1 },
  forward_compat_unknown_code: { metricCount: 2, uninterpretable: 1 },
};

const LEGACY_INPUTS = {
  flutter_rom_mmt_test_general: 4,
  native_bridge_label_only: 3,
  schema_doc_vocab: 3,
  trainer_ios_korean_enum: 5,
  status_shared_korean: 1,
  drawing_data_bytes: 0,
};

// Record-mode outputs committed later by DF-007 (flutter_*) and DF-009 (swift_*).
const RECORDED_BASES = ['finalized_no_metrics', 'draft_rom_mmt_pain', 'pending_member_draft'];
const RECORDED = new Map(
  RECORDED_BASES.flatMap((base) => [
    [`flutter_written_${base}`, 'dart'],
    [`swift_written_${base}`, 'swift'],
  ]),
);

const ENVELOPE_KEYS = ['_fixture', 'path', 'data'];
const FIXTURE_KEYS = ['id', 'description', 'writer', 'prdRefs', 'expect'];
const WRITERS = new Set(['synthetic', 'dart', 'swift']);
const EXPECT_KEYS = new Set(['roundTrip', 'metricCount', 'uninterpretable', 'legacyMetricCount']);
const TAGS = new Set(['$ts', '$serverTimestamp', '$bytes', '$int']);
const V2_FORBIDDEN_KEYS = ['diagnosis', 'structured', 'drawingData', 'nativeInkDataBase64'];

// Rule 3: synthetic identifiers and the two legacy exceptions.
const FX_ID = /^fx-[a-z0-9]+(-[a-z0-9]+)*$/;
const NATIVE_DOC_ID = /^native_fx_\d{8}$/;
const LEGACY_MEMBER_SEED = /^member-00000000-0000-4000-8000-00000000000\d$/;
const SYNTHETIC_NAME = /^가상 (회원|트레이너) [A-Z]$/;
const NAME_KEYS = new Set(['memberName', 'trainerName', 'displayName', 'name']);
// "두 글자 이상 한글 이름 + '회원'" with an exclusion list (AC-DF-005.4).
const REAL_NAME_PATTERN = /([가-힣]{2,})\s?회원/g;
const REAL_NAME_EXCLUSIONS = new Set(['가상', '대기']);
const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/g;
const PHONE = /01[016789]-?\d{3,4}-?\d{4}/;

// Demo literals that trainer_ios put into empty drafts (dfet:trainer_ios/DFETTrainer/Domain/SoapModels.swift:111-119,
// F-SOAP-06.3 counterexample). Hard-coded because trainer_ios/ is removed in P3; while the file exists the literals
// on those lines are read as well so the list cannot drift.
const DEMO_LITERALS = [
  '스쿼트 하강 구간에서 허리 불편감. 호흡 cue 후 안정.',
  'Hip hinge 패턴 제한, 우측 둔근 활성 저하. ROM/MMT 재측정 필요.',
  '요추 과신전 보상과 둔근 약화가 동반된 움직임 패턴 문제.',
  'dead bug 2세트, hip hinge 드릴, 다음 세션에서 ROM/MMT 재확인.',
  '고관절 굴곡 ROM',
  '흉추 회전 ROM',
  '우측 둔근 MMT',
  '말단 가동 범위 제한',
  '우측 회전 제한',
  '초기 수축 지연',
];
const SOAP_MODELS_SWIFT = path.join(REPO_ROOT, 'trainer_ios', 'DFETTrainer', 'Domain', 'SoapModels.swift');

// Legacy coverage required by AC-DF-005.2 (PRD §11.4 source vocabularies).
const LEGACY_VOCABS = {
  flutterEditor: ['rom', 'mmt', 'test', 'general'],
  trainerIos: ['ROM', '통증', 'MMT', '기능검사', '특수검사'],
  schemaDoc: ['pain', 'functional', 'specialTest'],
  nativeBridge: ['rom', 'mmt', 'exercise'],
};
const LEGACY_STATUSES = ['complete', '완료', '작성 중', '공유됨'];
const LEGACY_SIDES_KO = ['좌', '우', '양측', '해당 없음'];

// ---------------------------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------------------------

function listJson(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir).sort()) {
    const abs = path.join(dir, name);
    if (statSync(abs).isDirectory()) out.push(...listJson(abs));
    else if (name.endsWith('.json')) out.push(abs);
  }
  return out;
}

function listNames(dir) {
  return existsSync(dir) ? readdirSync(dir).sort() : [];
}

const ALL = listJson(FIXTURES_DIR).map((abs) => {
  const rel = path.relative(FIXTURES_DIR, abs).split(path.sep).join('/');
  const text = readFileSync(abs, 'utf8');
  return { rel, id: rel.replace(/\.json$/, ''), text, doc: JSON.parse(text) };
});
const byId = new Map(ALL.map((f) => [f.id, f]));
const isV2 = (f) => f.rel.startsWith('soap_v2/');
const isLegacyInput = (f) => f.rel.startsWith('soap_legacy/') && !f.rel.startsWith('soap_legacy/expected_v2/');
const V2_FILES = ALL.filter(isV2);
const LEGACY_FILES = ALL.filter(isLegacyInput);

const catalog = readContract('metric-catalog.v1.json');
const vocab = readContract('vocab.v1.json');
const METRICS = new Map(catalog.metrics.map((m) => [m.metricCode, m]));
const EXCLUDED = new Set(catalog.excludedMetricCodes);
const enumValues = (name) => new Set(vocab.enums[name].values);

// ---------------------------------------------------------------------------------------------
// Tree helpers
// ---------------------------------------------------------------------------------------------

const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const isTag = (v) => isObject(v) && Object.keys(v).some((k) => k.startsWith('$'));

// Yields { trail, key, value } for every property / array element below `node`.
function* nodes(node, trail = []) {
  if (Array.isArray(node)) {
    for (const [i, item] of node.entries()) {
      yield { trail: [...trail, i], key: i, value: item };
      yield* nodes(item, [...trail, i]);
    }
  } else if (isObject(node)) {
    for (const [k, v] of Object.entries(node)) {
      yield { trail: [...trail, k], key: k, value: v };
      yield* nodes(v, [...trail, k]);
    }
  }
}

function* strings(node) {
  if (typeof node === 'string') yield { trail: [], value: node };
  for (const n of nodes(node)) if (typeof n.value === 'string') yield n;
}

const where = (f, trail) => `${f.rel}#/${trail.join('/')}`;

const ISO_8601 = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/;
const BASE64 = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

// Returns a problem string for a malformed tag object, or null.
function tagProblem(value) {
  const keys = Object.keys(value);
  if (keys.length !== 1) return `tag object must have exactly one key, got ${JSON.stringify(keys)}`;
  const [tag] = keys;
  const v = value[tag];
  if (!TAGS.has(tag)) return `unknown tag ${tag}`;
  if (tag === '$ts' && !(typeof v === 'string' && ISO_8601.test(v) && !Number.isNaN(Date.parse(v)))) {
    return `$ts must be ISO 8601 with Z or offset, got ${JSON.stringify(v)}`;
  }
  if (tag === '$serverTimestamp' && v !== true) return `$serverTimestamp must be true, got ${JSON.stringify(v)}`;
  if (tag === '$bytes' && !(typeof v === 'string' && v.length > 0 && BASE64.test(v))) {
    return `$bytes must be padded standard base64, got ${JSON.stringify(v)}`;
  }
  if (tag === '$int' && !Number.isSafeInteger(v)) return `$int must be an integer, got ${JSON.stringify(v)}`;
  return null;
}

const tagName = (v) => (isTag(v) ? Object.keys(v)[0] : null);
const intValue = (v) => (tagName(v) === '$int' ? v.$int : undefined);
const numeric = (v) => (typeof v === 'number' ? v : intValue(v));
const nonBlank = (s) => typeof s === 'string' && s.trim().length > 0;
const docIdOf = (f) => f.doc.path.split('/').at(-1);
const metricsOf = (data) => data.objective?.metrics ?? [];

// ---------------------------------------------------------------------------------------------
// TC-DF005-01: file list, envelope, _fixture keys, synthetic-data rules
// ---------------------------------------------------------------------------------------------

test('TC-DF005-01 AC-DF-005.1 soap_v2/ has the five v2 inputs by name (plus only allowed record-mode outputs)', () => {
  const names = listNames(path.join(FIXTURES_DIR, 'soap_v2'));
  for (const base of Object.keys(V2_INPUTS)) assert.ok(names.includes(`${base}.json`), `missing soap_v2/${base}.json`);
  const allowed = new Set([...Object.keys(V2_INPUTS), ...RECORDED.keys()].map((b) => `${b}.json`));
  assert.deepEqual(names.filter((n) => !allowed.has(n)), [], 'unexpected entries in soap_v2/');
});

test('TC-DF005-01 AC-DF-005.2 soap_legacy/ has the six legacy inputs by name (expected_v2/ only mirrors input names)', () => {
  const names = listNames(path.join(FIXTURES_DIR, 'soap_legacy'));
  for (const base of Object.keys(LEGACY_INPUTS)) {
    assert.ok(names.includes(`${base}.json`), `missing soap_legacy/${base}.json`);
  }
  const allowed = new Set([...Object.keys(LEGACY_INPUTS).map((b) => `${b}.json`), 'expected_v2']);
  assert.deepEqual(names.filter((n) => !allowed.has(n)), [], 'unexpected entries in soap_legacy/');
  const expected = listNames(path.join(FIXTURES_DIR, 'soap_legacy', 'expected_v2'));
  const inputNames = new Set(Object.keys(LEGACY_INPUTS).map((b) => `${b}.json`));
  assert.deepEqual(expected.filter((n) => !inputNames.has(n)), [], 'expected_v2/ names must equal input names');
});

test('TC-DF005-01 contract paths that rule 4 retired do not exist', () => {
  assert.ok(!existsSync(path.join(FIXTURES_DIR, 'soap_legacy_expected')), 'use soap_legacy/expected_v2/');
  assert.ok(!existsSync(path.join(FIXTURES_DIR, 'soap_v2', 'migrated')), 'use soap_legacy/expected_v2/');
  assert.deepEqual(ALL.filter((f) => f.rel.endsWith('.expected_v2.json')).map((f) => f.rel), []);
});

test('TC-DF005-01 every fixture is canonical JSON (UTF-8, LF, 2-space indent, one trailing newline)', () => {
  assert.ok(ALL.length >= 11, `expected at least 11 fixtures, found ${ALL.length}`);
  for (const f of ALL) {
    assert.ok(!f.text.includes('\r'), `${f.rel}: CR found`);
    assert.equal(f.text, `${JSON.stringify(f.doc, null, 2)}\n`, `${f.rel}: not JSON.stringify(doc, null, 2) + "\\n"`);
  }
});

for (const f of ALL) {
  test(`TC-DF005-01 AC-DF-005.5 ${f.rel}: envelope is exactly {_fixture, path, data}; _fixture has the five keys`, () => {
    assert.ok(isObject(f.doc), 'top level must be an object');
    assert.deepEqual(Object.keys(f.doc), ENVELOPE_KEYS);
    const fx = f.doc._fixture;
    assert.ok(isObject(fx), '_fixture must be an object');
    assert.deepEqual(Object.keys(fx), FIXTURE_KEYS);
    assert.equal(fx.id, f.id, '_fixture.id must be the path under contracts/fixtures/ without .json');
    assert.ok(nonBlank(fx.description), '_fixture.description must be non-blank');
    assert.ok(WRITERS.has(fx.writer), `_fixture.writer must be synthetic|dart|swift, got ${fx.writer}`);
    assert.ok(Array.isArray(fx.prdRefs) && fx.prdRefs.length > 0, '_fixture.prdRefs must be a non-empty array');
    for (const ref of fx.prdRefs) assert.ok(nonBlank(ref), `prdRefs entries must be non-blank strings: ${ref}`);
    assert.ok(isObject(fx.expect) && Object.keys(fx.expect).length > 0, '_fixture.expect must be a non-empty object');
    for (const [k, v] of Object.entries(fx.expect)) {
      assert.ok(EXPECT_KEYS.has(k), `unknown expect key ${k}`);
      if (k === 'roundTrip') assert.equal(v, 'identical');
      else assert.ok(Number.isSafeInteger(v) && v >= 0, `expect.${k} must be a non-negative integer`);
    }
    assert.equal(typeof f.doc.path, 'string');
    assert.ok(isObject(f.doc.data), 'data must be an object');
  });
}

test('TC-DF005-01 AC-DF-005.1 v2 inputs: _fixture.expect matches the rule 4 table', () => {
  for (const [base, want] of Object.entries(V2_INPUTS)) {
    const f = byId.get(`soap_v2/${base}`);
    assert.ok(f, `soap_v2/${base}`);
    const { expect: e, writer } = f.doc._fixture;
    assert.equal(writer, 'synthetic', `${f.rel}: hand-written inputs use writer synthetic`);
    assert.equal(e.roundTrip, 'identical', `${f.rel}: roundTrip`);
    assert.equal(e.metricCount, want.metricCount, `${f.rel}: metricCount`);
    assert.equal(e.uninterpretable ?? 0, want.uninterpretable ?? 0, `${f.rel}: uninterpretable`);
    assert.equal(e.legacyMetricCount, undefined, `${f.rel}: legacyMetricCount is for legacy inputs only`);
  }
});

test('TC-DF005-01 record-mode outputs (if present) declare writer dart|swift and roundTrip identical', () => {
  for (const f of V2_FILES) {
    const base = path.basename(f.rel, '.json');
    if (!RECORDED.has(base)) continue;
    assert.equal(f.doc._fixture.writer, RECORDED.get(base), `${f.rel}: writer`);
    assert.equal(f.doc._fixture.expect.roundTrip, 'identical', `${f.rel}: roundTrip`);
  }
});

test('TC-DF005-01 AC-DF-005.2 legacy inputs: _fixture.expect is exactly the rule 4 legacyMetricCount', () => {
  for (const [base, count] of Object.entries(LEGACY_INPUTS)) {
    const f = byId.get(`soap_legacy/${base}`);
    assert.ok(f, `soap_legacy/${base}`);
    assert.equal(f.doc._fixture.writer, 'synthetic', `${f.rel}: writer`);
    assert.deepEqual(f.doc._fixture.expect, { legacyMetricCount: count }, `${f.rel}: expect`);
  }
});

test('TC-DF005-01 AC-DF-005.4 document IDs and uids start with fx- or are one of the two legacy exceptions', () => {
  const bad = [];
  for (const f of ALL) {
    const segments = f.doc.path.split('/');
    if (segments.length % 2 !== 0 || segments.some((s) => s.length === 0)) bad.push(`${f.rel}: path is not a document path`);
    for (const [i, seg] of segments.entries()) {
      if (i % 2 === 0) continue; // collection names
      const nativeOk = f.rel === 'soap_legacy/native_bridge_label_only.json' && NATIVE_DOC_ID.test(seg);
      if (!FX_ID.test(seg) && !nativeOk) bad.push(`${f.rel}: path document ID ${seg}`);
    }
    for (const { trail, key, value } of nodes(f.doc.data, ['data'])) {
      if (typeof key !== 'string') continue;
      const idKey = /^(id|uid)$|(Id|Uid)$/.test(key);
      const idListKey = /Ids$/.test(key);
      if (!idKey && !idListKey) continue;
      const values = idListKey ? value : [value];
      if (!Array.isArray(values)) {
        bad.push(`${where(f, trail)}: ID list is not an array`);
        continue;
      }
      for (const v of values) {
        if (v === null) continue;
        const seedOk = key === 'memberId' && isLegacyInput(f) && LEGACY_MEMBER_SEED.test(v);
        if (typeof v !== 'string' || (!FX_ID.test(v) && !seedOk)) bad.push(`${where(f, trail)}=${JSON.stringify(v)}`);
      }
    }
  }
  assert.deepEqual(bad, []);
});

test('TC-DF005-01 AC-DF-005.4 the legacy exceptions appear where rule 4 puts them', () => {
  const native = byId.get('soap_legacy/native_bridge_label_only').doc;
  assert.equal(native.path, 'soap_notes/native_fx_20260928');
  assert.equal(native.data.memberId, 'member-00000000-0000-4000-8000-000000000001');
});

test('TC-DF005-01 AC-DF-005.4 emails use @example.invalid only; no phone numbers', () => {
  const bad = [];
  for (const f of ALL) {
    for (const { trail, value } of strings(f.doc)) {
      for (const email of value.match(EMAIL) ?? []) {
        if (!/^[A-Za-z0-9._%+-]+@example\.invalid$/.test(email)) bad.push(`${where(f, trail)}: ${email}`);
      }
      if (PHONE.test(value)) bad.push(`${where(f, trail)}: phone-like ${value}`);
    }
  }
  assert.deepEqual(bad, []);
});

test('TC-DF005-01 AC-DF-005.4 real-name pattern count is 0 (names are "가상 회원 A" form)', () => {
  const bad = [];
  for (const f of ALL) {
    for (const { trail, key, value } of nodes(f.doc)) {
      if (NAME_KEYS.has(key) && value !== null && !(typeof value === 'string' && SYNTHETIC_NAME.test(value))) {
        bad.push(`${where(f, trail)}: name ${JSON.stringify(value)}`);
      }
    }
    for (const { trail, value } of strings(f.doc)) {
      for (const m of value.matchAll(REAL_NAME_PATTERN)) {
        if (!REAL_NAME_EXCLUSIONS.has(m[1])) bad.push(`${where(f, trail)}: ${m[0]}`);
      }
    }
  }
  assert.deepEqual(bad, []);
});

test('TC-DF005-01 AC-DF-005.3 finalized_no_metrics: empty metrics, quickNote present, no demo literal in any fixture', () => {
  const { data } = byId.get('soap_v2/finalized_no_metrics').doc;
  assert.deepEqual(data.objective.metrics, []);
  assert.ok(nonBlank(data.quickNote), 'quickNote original text is present');

  const literals = new Set(DEMO_LITERALS);
  if (existsSync(SOAP_MODELS_SWIFT)) {
    const lines = readFileSync(SOAP_MODELS_SWIFT, 'utf8').split('\n').slice(110, 119).join('\n');
    for (const m of lines.matchAll(/"([^"\\]*)"/g)) if (m[1].trim().length >= 4) literals.add(m[1]);
    for (const lit of DEMO_LITERALS) assert.ok(lines.includes(lit), `SoapModels.swift:111-119 no longer has "${lit}"`);
  }
  const bad = [];
  for (const f of ALL) {
    for (const { trail, value } of strings(f.doc)) {
      for (const lit of literals) if (value.includes(lit)) bad.push(`${where(f, trail)}: "${lit}"`);
    }
  }
  assert.deepEqual(bad, []);
});

// ---------------------------------------------------------------------------------------------
// TC-DF005-02: v2 data has no legacy-only keys, and follows the §9.3 shape
// ---------------------------------------------------------------------------------------------

for (const f of V2_FILES) {
  test(`TC-DF005-02 ${f.rel}: no ${V2_FORBIDDEN_KEYS.join('/')} keys anywhere in data`, () => {
    const bad = [];
    for (const { trail, key } of nodes(f.doc.data, ['data'])) if (V2_FORBIDDEN_KEYS.includes(key)) bad.push(where(f, trail));
    assert.deepEqual(bad, []);
  });

  test(`TC-DF005-02 ${f.rel}: v2 document invariants (§9.3, P0 DF-005 implementation notes)`, () => {
    const d = f.doc.data;
    const id = docIdOf(f);
    assert.equal(f.doc.path, `soap_notes/${id}`);
    assert.equal(intValue(d.schemaVersion) ?? d.schemaVersion, 2, 'schemaVersion 2');
    assert.equal(d.legalNature, 'coachingRecord');
    assert.equal(d.trainerId, d.authorUid, 'trainerId == authorUid');
    assert.ok(enumValues('soapStatus').has(d.status), `status ${d.status}`);
    assert.equal(tagName(d.sessionDate), '$ts', 'sessionDate is $ts');
    for (const k of ['createdAt', 'updatedAt']) {
      assert.ok(['$ts', '$serverTimestamp'].includes(tagName(d[k])), `${k} is $ts or $serverTimestamp`);
    }

    const hasMember = typeof d.memberUid === 'string';
    const hasPending = typeof d.pendingMemberId === 'string';
    assert.ok(hasMember !== hasPending, 'exactly one of memberUid / pendingMemberId has a value');
    assert.ok('memberUid' in d && 'pendingMemberId' in d, 'both member keys are written (one is null)');
    if (hasMember) assert.equal(d.memberId, d.memberUid, 'memberId mirrors memberUid');
    else assert.ok(!('memberId' in d), 'pending draft has no memberId');
    if ('isSharedWithMember' in d) assert.equal(d.isSharedWithMember, false, 'isSharedWithMember false only (D9)');

    if (d.status === 'finalized') {
      assert.ok(['$ts', '$serverTimestamp'].includes(tagName(d.finalizedAt)), 'finalizedAt');
      assert.ok(nonBlank(d.quickNote) || nonBlank(d.subjective?.chiefComplaint), '§6.4.4 #3 today record');
      assert.ok(nonBlank(d.plan?.nextSession), '§6.4.4 #4 next plan');
    } else {
      assert.ok(!('finalizedAt' in d), 'draft has no finalizedAt');
    }

    if ('inkPath' in d || 'inkRevision' in d) {
      assert.equal(tagName(d.inkRevision), '$int', 'inkRevision is $int');
      assert.ok(d.inkRevision.$int >= 1);
      assert.equal(d.inkPath, `soapInk/${id}/${d.inkRevision.$int}.drawing`);
    }

    if (d.subjective) {
      const { painNrs, painRegions } = d.subjective;
      if (painNrs !== undefined && painNrs !== null) {
        assert.equal(tagName(painNrs), '$int', 'painNrs is $int');
        assert.ok(painNrs.$int >= 0 && painNrs.$int <= 10, 'painNrs 0..10');
      }
      const regions = enumValues('regionCode');
      for (const r of painRegions ?? []) assert.ok(regions.has(r), `painRegions ${r} not in vocab regionCode`);
    }

    if (d.objective) {
      assert.ok(Array.isArray(d.objective.metrics), 'objective.metrics array');
      assert.deepEqual(Object.keys(d.objective.refs ?? {}).sort(), [
        'bodyCompositionRecordIds',
        'bodyScanIds',
        'circumferenceMeasurementIds',
        'postureAssessmentIds',
      ]);
      assert.ok(Array.isArray(d.objective.snapshots), 'objective.snapshots array');
    }
  });
}

// ---------------------------------------------------------------------------------------------
// TC-DF005-03: legacy coverage and legacyMetricCount
// ---------------------------------------------------------------------------------------------

const legacyMetrics = (f) => f.doc.data.structured?.metrics;
const legacyStatus = (f) => f.doc.data.structured?.workflow?.status;
const legacyTypes = (f) => (legacyMetrics(f) ?? []).map((m) => m.type);

for (const f of LEGACY_FILES) {
  test(`TC-DF005-03 ${f.rel}: legacyMetricCount equals structured.metrics length; v1 shape`, () => {
    const d = f.doc.data;
    assert.ok(!('schemaVersion' in d), 'legacy documents have no schemaVersion');
    assert.ok(Array.isArray(legacyMetrics(f)), 'structured.metrics array');
    assert.equal(legacyMetrics(f).length, f.doc._fixture.expect.legacyMetricCount);
    for (const m of legacyMetrics(f)) {
      assert.equal(typeof m.type, 'string', 'metric type is a string');
      assert.equal(typeof m.value, 'string', 'legacy value is stored as a string (Flutter compat)');
    }
    for (const k of ['date', 'createdAt', 'updatedAt']) assert.equal(tagName(d[k]), '$int', `${k} millis is $int`);
  });
}

test('TC-DF005-03 AC-DF-005.2 each file carries the rule 4 vocabulary, status and category notation', () => {
  const get = (b) => byId.get(`soap_legacy/${b}`);

  const flutter = get('flutter_rom_mmt_test_general');
  assert.deepEqual(legacyTypes(flutter), LEGACY_VOCABS.flutterEditor);
  const values = legacyMetrics(flutter).map((m) => m.value);
  assert.ok(values.includes('110-120') && values.includes('4+'), 'unparsable range and symbol values');
  assert.equal(legacyStatus(flutter), 'complete');
  assert.ok(flutter.doc.data.structured.workflow.completedCategories.includes('subjective'));

  const native = get('native_bridge_label_only');
  assert.deepEqual(legacyTypes(native), LEGACY_VOCABS.nativeBridge);
  for (const m of legacyMetrics(native)) {
    assert.ok(nonBlank(m.label) && m.value === '', `bridge metric ${m.type} is label only`);
  }
  assert.ok(nonBlank(native.doc.data.diagnosis), 'diagnosis autofill string');
  assert.equal(native.doc.data.isSharedWithMember, true);
  const ink = native.doc.data.structured.subjective.nativeInkDataBase64;
  assert.equal(typeof ink, 'string', 'nativeInkDataBase64 is a plain base64 string, as the bridge wrote it');
  assert.equal(Buffer.from(ink, 'base64').length, 64, 'nativeInkDataBase64 decodes to 64 bytes');

  const schemaDoc = get('schema_doc_vocab');
  assert.deepEqual(legacyTypes(schemaDoc), LEGACY_VOCABS.schemaDoc);
  assert.equal(legacyStatus(schemaDoc), '완료');

  const ios = get('trainer_ios_korean_enum');
  assert.deepEqual([...legacyTypes(ios)].sort(), [...LEGACY_VOCABS.trainerIos].sort());
  assert.deepEqual(
    [...new Set(legacyMetrics(ios).map((m) => m.side))].sort(),
    [...LEGACY_SIDES_KO].sort(),
    'all four Korean sides',
  );
  assert.ok(legacyMetrics(ios).some((m) => m.unit === '도'), 'unit 도');
  assert.equal(legacyStatus(ios), '작성 중');
  assert.deepEqual(ios.doc.data.structured.workflow.completedCategories, ['S']);

  const shared = get('status_shared_korean');
  assert.equal(legacyStatus(shared), '공유됨');
  assert.equal(shared.doc.data.isSharedWithMember, true);
  assert.deepEqual(legacyTypes(shared), ['general']);
  assert.equal(legacyMetrics(shared)[0].value, '');

  const drawing = get('drawing_data_bytes');
  assert.equal(tagName(drawing.doc.data.drawingData), '$bytes', 'drawingData is $bytes');
  assert.ok(Buffer.from(drawing.doc.data.drawingData.$bytes, 'base64').length > 0);
});

test('TC-DF005-03 AC-DF-005.2 the legacy set covers four vocabularies, both status and category notations, inline ink', () => {
  const types = new Set(LEGACY_FILES.flatMap(legacyTypes));
  for (const [name, list] of Object.entries(LEGACY_VOCABS)) {
    for (const t of list) assert.ok(types.has(t), `vocabulary ${name}: type ${t} missing`);
  }
  const statuses = new Set(LEGACY_FILES.map(legacyStatus));
  for (const s of LEGACY_STATUSES) assert.ok(statuses.has(s), `status ${s} missing`);
  const categories = new Set(LEGACY_FILES.flatMap((f) => f.doc.data.structured?.workflow?.completedCategories ?? []));
  assert.ok(categories.has('S') && categories.has('subjective'), 'completedCategories S and subjective');
  const keys = new Set(LEGACY_FILES.flatMap((f) => [...nodes(f.doc.data)].map((n) => n.key)));
  assert.ok(keys.has('nativeInkDataBase64') && keys.has('drawingData'), 'inline ink: nativeInkDataBase64 and drawingData');
  assert.ok(
    LEGACY_FILES.some((f) => LEGACY_MEMBER_SEED.test(f.doc.data.memberId ?? '')),
    'member- seed memberId (MIG-07)',
  );
});

// ---------------------------------------------------------------------------------------------
// TC-DF005-04: type tags, metric codes against the catalog
// ---------------------------------------------------------------------------------------------

for (const f of ALL) {
  test(`TC-DF005-04 AC-DF-005.5 ${f.rel}: tags only inside data, and only $ts/$serverTimestamp/$bytes/$int`, () => {
    const bad = [];
    for (const part of ['_fixture', 'path']) {
      for (const { trail, key } of nodes({ [part]: f.doc[part] })) {
        if (typeof key === 'string' && key.startsWith('$')) bad.push(`${where(f, trail)}: tag outside data`);
      }
    }
    for (const { trail, key, value } of nodes(f.doc.data, ['data'])) {
      if (isObject(value) && isTag(value)) {
        const problem = tagProblem(value);
        if (problem) bad.push(`${where(f, trail)}: ${problem}`);
      } else if (typeof key === 'string' && key.startsWith('$') && !TAGS.has(key)) {
        bad.push(`${where(f, trail)}: unknown $ key`);
      }
      if (typeof value === 'string' && /^<serverTimestamp>$/.test(value)) bad.push(`${where(f, trail)}: reading notation`);
    }
    assert.deepEqual(bad, []);
  });
}

for (const f of V2_FILES) {
  test(`TC-DF005-04 AC-DF-005.1 ${f.rel}: metrics match expect and the catalog (except expect.uninterpretable rows)`, () => {
    const d = f.doc.data;
    const { expect: e } = f.doc._fixture;
    const rows = metricsOf(d);
    assert.equal(rows.length, e.metricCount, 'expect.metricCount');
    const unknown = rows.filter((r) => !METRICS.has(r.metricCode));
    assert.equal(unknown.length, e.uninterpretable ?? 0, 'unknown metricCode rows == expect.uninterpretable');

    const sides = enumValues('side');
    for (const [i, r] of rows.entries()) {
      const at = `objective.metrics[${i}]`;
      assert.equal(typeof r.metricCode, 'string', `${at}.metricCode`);
      assert.ok(!EXCLUDED.has(r.metricCode), `${at}: excluded metricCode ${r.metricCode}`);
      assert.ok(numeric(r.value) !== undefined, `${at}.value must be a number or $int`);
      assert.ok(sides.has(r.side), `${at}.side ${r.side}`);
      const m = METRICS.get(r.metricCode);
      if (!m) continue; // uninterpretable row: preserved as-is (F-SOAP-06.2)
      assert.equal(m.storage?.field, 'objective.metrics', `${at}: ${r.metricCode} is not an SOAP O metric`);
      assert.equal(r.unit, m.unit, `${at}.unit`);
      assert.ok(m.allowedSourceGrades.includes(r.sourceGrade), `${at}.sourceGrade ${r.sourceGrade}`);
      if (m.sideRule === 'leftRightBilateral') assert.ok(r.side !== 'none', `${at}.side must be left|right|bilateral`);
      if (r.metricCode === 'romDeg') {
        assert.ok(enumValues('joint').has(r.joint), `${at}.joint ${r.joint}`);
        assert.ok(enumValues('motion').has(r.motion), `${at}.motion ${r.motion}`);
        assert.ok(enumValues('activeOrPassive').has(r.activeOrPassive), `${at}.activeOrPassive`);
      }
      if (r.metricCode === 'mmtGrade') {
        assert.ok(enumValues('muscleGroup').has(r.muscleGroup), `${at}.muscleGroup ${r.muscleGroup}`);
        assert.equal(tagName(r.value), '$int', `${at}.value must be $int`);
        assert.ok(r.value.$int >= 0 && r.value.$int <= 5, `${at}.value 0..5`);
      }
    }

    const refIds = new Set(Object.values(d.objective?.refs ?? {}).flat());
    for (const [i, s] of (d.objective?.snapshots ?? []).entries()) {
      const at = `objective.snapshots[${i}]`;
      const m = METRICS.get(s.metricCode);
      assert.ok(m, `${at}.metricCode ${s.metricCode} must be in the catalog`);
      assert.ok(refIds.has(s.refId), `${at}.refId ${s.refId} must be listed in objective.refs`);
      assert.equal(s.unit, m.unit, `${at}.unit`);
      assert.ok(sides.has(s.side), `${at}.side`);
      assert.ok(m.allowedSourceGrades.includes(s.sourceGrade), `${at}.sourceGrade ${s.sourceGrade}`);
      assert.equal(s.changeStatus, 'pendingPolicy', `${at}.changeStatus is pendingPolicy before P3 (ADR-009)`);
      for (const k of ['reasonCode', 'policyVersion', 'mdcSource']) assert.ok(k in s, `${at}.${k} key present`);
      if (s.mdcSource !== null) assert.ok(enumValues('mdcSource').has(s.mdcSource));
      assert.equal(tagName(s.measuredAt), '$ts', `${at}.measuredAt is $ts`);
      const v = numeric(s.value);
      assert.ok(v !== undefined, `${at}.value numeric`);
      if (m.range) {
        assert.ok(m.range.minExclusive ? v > m.range.min : v >= m.range.min, `${at}.value >= range.min`);
        assert.ok(v <= m.range.max, `${at}.value <= range.max`);
      }
    }
  });
}

test('TC-DF005-04 AC-DF-005.1 v2 input contents match the rule 4 table', () => {
  const get = (b) => byId.get(`soap_v2/${b}`).doc.data;

  const fin = get('finalized_no_metrics');
  assert.equal(fin.status, 'finalized');
  assert.deepEqual(metricsOf(fin), []);

  const draft = get('draft_rom_mmt_pain');
  assert.equal(draft.status, 'draft');
  assert.deepEqual(metricsOf(draft).map((r) => r.metricCode).sort(), ['mmtGrade', 'romDeg']);
  assert.equal(tagName(draft.subjective.painNrs), '$int');
  assert.ok(draft.subjective.painRegions.length > 0, 'painRegions');

  const pending = get('pending_member_draft');
  assert.equal(pending.memberUid, null);
  assert.ok(!('memberId' in pending));
  assert.equal(pending.pendingMemberId, 'fx-pending-001');

  const refs = get('refs_snapshots_pending_policy');
  assert.ok(Object.values(refs.objective.refs).some((ids) => ids.length > 0), 'objective.refs has IDs');
  assert.ok(refs.objective.snapshots.length > 0, 'snapshots present');
  assert.ok(refs.objective.snapshots.every((s) => s.changeStatus === 'pendingPolicy'));

  const fwd = get('forward_compat_unknown_code');
  assert.deepEqual(
    metricsOf(fwd).filter((r) => !METRICS.has(r.metricCode)).map((r) => r.metricCode),
    ['futureMetricX'],
  );
  assert.equal(metricsOf(fwd).filter((r) => METRICS.has(r.metricCode)).length, 1, 'one normal row');
});
