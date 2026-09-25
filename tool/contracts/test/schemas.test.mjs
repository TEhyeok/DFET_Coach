// TC-DF006-01~04: document JSON Schemas (schemas/*.schema.json) and docs/firestore_schema.md follow
// PRD §9.2·§9.3 (docs/v1/backlog/P0.md#df-006). The schemas validate the fixture envelope `data` in the
// cross-client neutral notation ($ts / $serverTimestamp / $int tags, contracts/fixtures/README.md rule 2).
// ajv comes from tool/package.json (DF-004).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

import Ajv2020Module from 'ajv/dist/2020.js';

import { REPO_ROOT, readContract } from './helpers.mjs';

const Ajv2020 = Ajv2020Module.default ?? Ajv2020Module;

const SCHEMAS_DIR = path.join(REPO_ROOT, 'schemas');
const V2_DIR = path.join(REPO_ROOT, 'contracts', 'fixtures', 'soap_v2');
const LEGACY_DIR = path.join(REPO_ROOT, 'contracts', 'fixtures', 'soap_legacy');

// AC-DF-006.3: the seven new document schemas.
const DOCUMENT_SCHEMAS = [
  'soap-note-v2',
  'soap-addendum',
  'posture-assessment',
  'body-composition-record',
  'circumference-measurement',
  'member-summary',
  'consent-record',
];

// Contract rule 4: the five v2 inputs. Record-mode outputs (*_written_*) are picked up from the directory.
const V2_INPUTS = [
  'finalized_no_metrics',
  'draft_rom_mmt_pain',
  'pending_member_draft',
  'refs_snapshots_pending_policy',
  'forward_compat_unknown_code',
];

const FLAG_KEYS = ['gut', 'blood', 'insights', 'bodyAssessment', 'bodyComposition', 'soapV2', 'memberShare', 'lidarBeta'];

// Tag $defs as the card (implementation notes) defines them. Each schema that uses a tag carries the same copy.
const TS_DEF_SHAPE = [
  { type: 'object', required: ['$ts'], additionalProperties: false },
  { type: 'object', required: ['$serverTimestamp'], additionalProperties: false },
];
const INT_DEF = {
  type: 'object',
  required: ['$int'],
  properties: { $int: { type: 'integer' } },
  additionalProperties: false,
};
const METRIC_CODE_DEF = { type: 'string', pattern: '^[a-z][A-Za-z0-9]*$', maxLength: 64 };

// ---------------------------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------------------------

function readJsonFile(abs) {
  return JSON.parse(readFileSync(abs, 'utf8'));
}

function schemaPath(name) {
  return path.join(SCHEMAS_DIR, `${name}.schema.json`);
}

const SCHEMAS = Object.fromEntries(DOCUMENT_SCHEMAS.map((name) => [name, readJsonFile(schemaPath(name))]));

// Same options as the DF-004 generator (tool/contracts/generate.mjs), no formats: the schemas use patterns only.
function compile(schema) {
  const ajv = new Ajv2020({ allErrors: true, strict: true, strictTypes: false, strictRequired: false });
  return ajv.compile(schema);
}

const VALIDATORS = Object.fromEntries(DOCUMENT_SCHEMAS.map((name) => [name, compile(SCHEMAS[name])]));

function check(name, data) {
  const validate = VALIDATORS[name];
  const ok = validate(data);
  return { ok, errors: validate.errors ?? [] };
}

function describeErrors(errors) {
  return errors.map((e) => `${e.instancePath || '/'} ${e.keyword}: ${e.message}`).join('\n');
}

function assertValid(name, data, label) {
  const { ok, errors } = check(name, data);
  assert.ok(ok, `${label} should pass ${name}:\n${describeErrors(errors)}`);
}

function assertInvalid(name, data, label, { keyword, instancePath } = {}) {
  const { ok, errors } = check(name, data);
  assert.equal(ok, false, `${label} should fail ${name}`);
  if (keyword || instancePath !== undefined) {
    const hit = errors.some(
      (e) => (!keyword || e.keyword === keyword) && (instancePath === undefined || e.instancePath === instancePath),
    );
    assert.ok(hit, `${label}: expected ${keyword ?? '*'} at ${instancePath ?? '*'}, got:\n${describeErrors(errors)}`);
  }
}

function fixtureFiles(dir) {
  return readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .sort();
}

function fixtureData(dir, file) {
  return readJsonFile(path.join(dir, file)).data;
}

function v2Data(base) {
  return structuredClone(fixtureData(V2_DIR, `${base}.json`));
}

// Resolves a local "#/$defs/x" reference; returns the node itself otherwise.
function deref(schema, node) {
  if (node && typeof node.$ref === 'string' && node.$ref.startsWith('#/$defs/')) {
    return schema.$defs[node.$ref.slice('#/$defs/'.length)];
  }
  return node;
}

// Every `enum` array in a schema tree, with its JSON pointer.
function collectEnums(node, trail = '', out = []) {
  if (Array.isArray(node)) {
    node.forEach((item, i) => collectEnums(item, `${trail}/${i}`, out));
  } else if (node !== null && typeof node === 'object') {
    for (const [k, v] of Object.entries(node)) {
      if (k === 'enum' && Array.isArray(v)) out.push({ pointer: trail, values: v });
      else collectEnums(v, `${trail}/${k}`, out);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Synthetic valid documents for the non-SOAP schemas (rule 3 identifiers, V1-05 §4 examples in tag notation).
// ---------------------------------------------------------------------------------------------

const TS = (iso) => ({ $ts: iso });
const SERVER_TS = { $serverTimestamp: true };
const INT = (n) => ({ $int: n });

const SAMPLES = {
  'soap-addendum': {
    authorUid: 'fx-trainer-001',
    createdAt: SERVER_TS,
    reason: '정보주체 정정 요구',
    text: '통증 부위를 허리가 아니라 오른쪽 엉덩이로 정정',
    changedFields: ['subjective.painRegions'],
    previousValues: { 'subjective.painRegions': ['lowerBack'] },
  },
  'posture-assessment': {
    memberUid: 'fx-member-001',
    pendingMemberId: null,
    trainerId: 'fx-trainer-001',
    authorUid: 'fx-trainer-001',
    capturedAt: TS('2026-10-01T10:05:12+09:00'),
    protocolVersion: 'posture-v1',
    stationProfileId: 'fx-station-001',
    landmarkEngine: { name: 'appleVision2D', version: 'iOS17.4' },
    device: { model: 'iPad14,5', osVersion: '17.4' },
    captureConditions: {
      clothing: 'fitted',
      barefoot: true,
      markersPlaced: true,
      verbalConsentCheck: true,
      cameraHeightCm: 100,
      cameraDistanceM: 3,
      levelDeg: 0.4,
      pitchDeg: -0.8,
    },
    views: [
      {
        view: 'sagittalLeft',
        photoPath: 'postureAssessments/fx-posture-001/sagittalLeft.jpg',
        thumbPath: 'postureAssessments/fx-posture-001/sagittalLeft_thumb.jpg',
        maskedThumbPath: 'postureAssessments/fx-posture-001/sagittalLeft_masked_thumb.jpg',
        imageRotationDeg: 0.4,
        landmarks: [
          {
            code: 'tragusLeft',
            x: 0.512,
            y: 0.231,
            origin: 'manual',
            confirmed: true,
            suggested: { x: 0.505, y: 0.236, confidence: 0.71 },
          },
          { code: 'c7', x: 0.468, y: 0.302, origin: 'manual', confirmed: true },
        ],
      },
    ],
    metrics: [
      { metricCode: 'craniovertebralAngle', value: 48.2, unit: 'deg', side: 'none', sourceGrade: 'photoManual' },
    ],
    status: 'confirmed',
    isBaseline: true,
    supersedesId: null,
    retestGroupId: null,
    legalNature: 'coachingRecord',
    schemaVersion: 1,
    createdAt: SERVER_TS,
    updatedAt: SERVER_TS,
  },
  'body-composition-record': {
    memberUid: null,
    pendingMemberId: 'fx-pending-001',
    trainerId: 'fx-trainer-001',
    enteredBy: 'fx-trainer-001',
    source: 'manualEntry',
    sourceGrade: 'device',
    deviceModel: 'InBody 570',
    measuredAt: TS('2026-12-07T08:40:00+09:00'),
    fasting: 'yes',
    timeOfDayBand: 'morning',
    values: { weightKg: 62.4, bodyFatPercent: 24.1, skeletalMuscleMassKg: 25.3 },
    derived: { bmi: 22.9, heightCmUsed: 165, heightMeasuredAt: TS('2026-11-23T10:00:00+09:00'), sourceGrade: 'derived' },
    reportPhotoPath: null,
    externalId: null,
    idempotencyKey: null,
    rawPath: null,
    status: 'active',
    legalNature: 'coachingRecord',
    schemaVersion: 1,
    createdAt: SERVER_TS,
    updatedAt: SERVER_TS,
  },
  'circumference-measurement': {
    memberUid: 'fx-member-001',
    pendingMemberId: null,
    trainerId: 'fx-trainer-001',
    authorUid: 'fx-trainer-001',
    metricCode: 'thighCircumference',
    side: 'left',
    valueCm: 54.2,
    sourceGrade: 'tape',
    protocolId: 'custom',
    protocolVersion: 'circ-v1',
    landmarkNote: '슬개골 상연 위 15cm',
    conditionsNote: null,
    measuredAt: TS('2026-12-14T11:10:00+09:00'),
    trialIndex: INT(2),
    scanId: null,
    referenceTapeCm: null,
    validationStatus: 'validated',
    isBeta: false,
    status: 'active',
    legalNature: 'coachingRecord',
    schemaVersion: 1,
    createdAt: SERVER_TS,
    updatedAt: SERVER_TS,
  },
  'member-summary': {
    memberUid: 'fx-member-001',
    trainerId: 'fx-trainer-001',
    sharedByUid: 'fx-trainer-001',
    sharedByDisplayName: '가상 트레이너 A',
    sourceType: 'bodyReport',
    sourceIds: ['fx-posture-001', 'fx-bodycomp-001'],
    title: '1월 체형 확인 결과',
    body: '옆모습 목 각도를 사진으로 확인했어요.',
    highlights: [
      {
        refId: 'fx-posture-001',
        metricCode: 'craniovertebralAngle',
        value: 48.2,
        unit: 'deg',
        side: 'none',
        sourceGrade: 'photoManual',
        measuredAt: TS('2027-01-18T10:05:12+09:00'),
        changeStatus: null,
        reasonCode: null,
        mdcSource: null,
        mdc: null,
        seriesKey: 'sk-fx-001',
        comparedTo: null,
      },
    ],
    sharedPhotoPaths: ['postureAssessments/fx-posture-001/sagittalLeft_masked_thumb.jpg'],
    nextPlan: '다음 주에 같은 조건으로 다시 확인해요.',
    policyVersion: null,
    status: 'shared',
    sharedAt: SERVER_TS,
    revokedAt: null,
    firstViewedAt: null,
    schemaVersion: 1,
  },
  'consent-record': {
    subjectUid: null,
    pendingMemberId: 'fx-pending-001',
    consentType: 'healthData',
    action: 'grant',
    documentVersion: 'healthData--1.0',
    channel: 'trainerDeviceInPerson',
    recordedAt: SERVER_TS,
    recordedBy: 'fx-trainer-001',
    capturedAt: TS('2026-11-16T10:01:00+09:00'),
    signaturePath: 'consentSignatures/fx-consent-001.png',
    reconfirmedAt: null,
    reconfirmOf: null,
    clientCaptureId: 'fx-capture-001',
    schemaVersion: 1,
  },
};

function sample(name) {
  return structuredClone(SAMPLES[name]);
}

// ---------------------------------------------------------------------------------------------
// AC-DF-006.3 — files, dialect, tags
// ---------------------------------------------------------------------------------------------

test('AC-DF-006.3 the seven document schemas exist, use draft 2020-12 and compile in ajv strict mode', () => {
  for (const name of DOCUMENT_SCHEMAS) {
    const schema = SCHEMAS[name];
    assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema', name);
    assert.equal(schema.$id, `https://dfet.co.kr/schemas/${name}.schema.json`, name);
    assert.equal(schema.type, 'object', name);
    assert.equal(schema.additionalProperties, false, `${name}: top-level additionalProperties must be false`);
    assert.equal(typeof VALIDATORS[name], 'function', name);
  }
});

test('AC-DF-006.3 each schema description says it validates the neutral notation, not Firestore native types', () => {
  for (const name of DOCUMENT_SCHEMAS) {
    const { description } = SCHEMAS[name];
    assert.match(description, /Firestore 네이티브 타입이 아니라 교차 클라이언트 중립 표기/, name);
    assert.match(description, /\$ts/, name);
  }
});

test('AC-DF-006.3 tag $defs match the fixture contract and are identical across the schemas', () => {
  const copies = { ts: [], int: [], id: [], nullableId: [] };
  for (const name of DOCUMENT_SCHEMAS) {
    const defs = SCHEMAS[name].$defs;
    assert.ok(defs?.ts, `${name}: $defs/ts is required`);
    const shape = defs.ts.oneOf.map(({ type, required, additionalProperties }) => ({ type, required, additionalProperties }));
    assert.deepEqual(shape, TS_DEF_SHAPE, `${name}: $defs/ts`);
    if (defs.int) {
      const { description, ...rest } = defs.int;
      assert.deepEqual(rest, INT_DEF, `${name}: $defs/int`);
    }
    assert.equal(defs.bytes, undefined, `${name}: $defs/bytes is legacy-only and must not be in v2 schemas`);
    for (const key of Object.keys(copies)) if (defs[key]) copies[key].push([name, defs[key]]);
  }
  for (const [key, list] of Object.entries(copies)) {
    for (const [name, def] of list.slice(1)) assert.deepEqual(def, list[0][1], `${name}: $defs/${key} differs from ${list[0][0]}`);
  }
  assert.equal(copies.int.length >= 2, true, '$defs/int must be used (soap-note-v2, circumference-measurement)');
});

test('AC-DF-006.3 soap-note-v2 metricCode is the card pattern, not a catalog enum (F-SOAP-06.2)', () => {
  const schema = SCHEMAS['soap-note-v2'];
  assert.deepEqual(
    (({ type, pattern, maxLength }) => ({ type, pattern, maxLength }))(schema.$defs.metricCode),
    METRIC_CODE_DEF,
  );
  const catalogCodes = new Set(readContract('metric-catalog.v1.json').metrics.map((m) => m.metricCode));
  for (const { pointer, values } of collectEnums(schema)) {
    const leaked = values.filter((v) => catalogCodes.has(v));
    assert.deepEqual(leaked, [], `${pointer}: catalog metric codes must not be enumerated`);
  }
});

test('AC-DF-006.3 schemas neither reference contracts-meta.schema.json (DF-004) nor use the legacy $bytes tag', () => {
  for (const name of DOCUMENT_SCHEMAS) {
    const text = readFileSync(schemaPath(name), 'utf8');
    assert.doesNotMatch(text, /contracts-meta/, name);
    assert.doesNotMatch(text, /\$bytes/, name);
  }
});

// ---------------------------------------------------------------------------------------------
// TC-DF006-01 — every v2 fixture passes soap-note-v2
// ---------------------------------------------------------------------------------------------

test('TC-DF006-01 AC-DF-006.3 every v2 fixture data (inputs and *_written_* records) passes soap-note-v2', () => {
  const files = fixtureFiles(V2_DIR);
  for (const base of V2_INPUTS) assert.ok(files.includes(`${base}.json`), `missing v2 input ${base}.json`);
  for (const file of files) assertValid('soap-note-v2', fixtureData(V2_DIR, file), `soap_v2/${file}`);
});

test('TC-DF006-01 AC-DF-006.3 forward_compat_unknown_code passes: format only, catalog membership not checked', () => {
  const data = v2Data('forward_compat_unknown_code');
  const codes = data.objective.metrics.map((m) => m.metricCode);
  const catalog = new Set(readContract('metric-catalog.v1.json').metrics.map((m) => m.metricCode));
  assert.ok(codes.some((c) => !catalog.has(c)), 'fixture must contain a code outside the catalog');
  assertValid('soap-note-v2', data, 'forward_compat_unknown_code');
});

for (const code of ['ROM', '통증']) {
  test(`TC-DF006-01 metricCode "${code}" fails the pattern`, () => {
    const data = v2Data('draft_rom_mmt_pain');
    data.objective.metrics[0].metricCode = code;
    assertInvalid('soap-note-v2', data, `metricCode ${code}`, {
      keyword: 'pattern',
      instancePath: '/objective/metrics/0/metricCode',
    });
  });
}

test('TC-DF006-01 AC-DF-006.1 legacy (v1) fixtures do not pass soap-note-v2 (write forbidden after MIG-03)', () => {
  const files = fixtureFiles(LEGACY_DIR);
  assert.ok(files.length >= 6, 'legacy inputs are expected');
  for (const file of files) assertInvalid('soap-note-v2', fixtureData(LEGACY_DIR, file), `soap_legacy/${file}`);
});

// ---------------------------------------------------------------------------------------------
// TC-DF006-02 — the card's variant table
// ---------------------------------------------------------------------------------------------

test('TC-DF006-02 AC-DF-006.3 adding diagnosis to a v2 fixture fails (additionalProperties:false)', () => {
  const data = v2Data('finalized_no_metrics');
  data.diagnosis = '합성 진단 문자열';
  assertInvalid('soap-note-v2', data, 'diagnosis', { keyword: 'additionalProperties', instancePath: '' });
});

test('TC-DF006-02 adding structured to a v2 fixture fails', () => {
  const data = v2Data('finalized_no_metrics');
  data.structured = { subjective: { chiefComplaint: '합성' } };
  assertInvalid('soap-note-v2', data, 'structured', { keyword: 'additionalProperties', instancePath: '' });
});

test('TC-DF006-02 isSharedWithMember:true fails', () => {
  const data = v2Data('finalized_no_metrics');
  data.isSharedWithMember = true;
  assertInvalid('soap-note-v2', data, 'isSharedWithMember:true', { keyword: 'const', instancePath: '/isSharedWithMember' });
});

test('TC-DF006-02 AC-DF-006.4 empty values fails (minProperties:1)', () => {
  const doc = sample('body-composition-record');
  doc.values = {};
  assertInvalid('body-composition-record', doc, 'values {}', { keyword: 'minProperties', instancePath: '/values' });
});

test('TC-DF006-02 AC-DF-006.4 weightKg:0 fails (exclusiveMinimum:0)', () => {
  const doc = sample('body-composition-record');
  doc.values = { weightKg: 0 };
  assertInvalid('body-composition-record', doc, 'weightKg 0', {
    keyword: 'exclusiveMinimum',
    instancePath: '/values/weightKg',
  });
});

test('TC-DF006-02 AC-DF-006.4 bodyFatPercent:0 passes (0–100)', () => {
  const doc = sample('body-composition-record');
  doc.values = { bodyFatPercent: 0 };
  assertValid('body-composition-record', doc, 'bodyFatPercent 0');
});

// ---------------------------------------------------------------------------------------------
// AC-DF-006.4 — body-composition-record carries the v2 InBody fields
// ---------------------------------------------------------------------------------------------

test('AC-DF-006.4 body-composition-record: source enum, nullable v2 server-only fields, six values keys', () => {
  const schema = SCHEMAS['body-composition-record'];
  const props = schema.properties;
  assert.deepEqual(deref(schema, props.source).enum, ['manualEntry', 'inbodyApi', 'healthKit']);
  for (const key of ['externalId', 'idempotencyKey', 'rawPath']) {
    assert.ok(props[key], `${key} must exist`);
    assert.match(props[key].description, /v2 서버 전용/, `${key}: v2 server-only note`);
    assert.equal(schema.required.includes(key), false, `${key} is optional in v1`);
    const doc = sample('body-composition-record');
    doc[key] = null;
    assertValid('body-composition-record', doc, `${key}: null`);
  }
  const values = props.values;
  assert.equal(values.minProperties, 1);
  assert.equal(values.additionalProperties, false);
  assert.deepEqual(Object.keys(values.properties).sort(), [
    'bodyFatMassKg',
    'bodyFatPercent',
    'skeletalMuscleMassKg',
    'totalBodyWaterL',
    'visceralFatLevel',
    'weightKg',
  ]);
  assert.equal(values.properties.bodyFatPercent.minimum, 0);
  assert.equal(values.properties.bodyFatPercent.maximum, 100);
  for (const [key, def] of Object.entries(values.properties)) {
    if (key !== 'bodyFatPercent') assert.equal(def.exclusiveMinimum, 0, `${key}: exclusiveMinimum 0`);
  }
});

test('AC-DF-006.4 AC-BC-04.1 an inbodyApi record with externalId, idempotencyKey and rawPath passes', () => {
  const doc = sample('body-composition-record');
  Object.assign(doc, {
    source: 'inbodyApi',
    externalId: 'fx-inbody-result-001',
    idempotencyKey: 'fx-idem-001',
    rawPath: 'clinical-ingest/bodycomp/fx-job-001/payload.json',
  });
  assertValid('body-composition-record', doc, 'inbodyApi');
  doc.values = { ...doc.values, bmi: 22.9 };
  assertInvalid('body-composition-record', doc, 'bmi inside values', { keyword: 'additionalProperties', instancePath: '/values' });
});

// ---------------------------------------------------------------------------------------------
// AC-DF-006.5 — feature flags example (TC-DF006-03 runs `jq empty schemas/*.json` in CI)
// ---------------------------------------------------------------------------------------------

test('AC-DF-006.5 feature-flags.example.json has the eight keys, all false', () => {
  const flags = readJsonFile(path.join(SCHEMAS_DIR, 'feature-flags.example.json'));
  assert.deepEqual(Object.keys(flags).sort(), [...FLAG_KEYS].sort());
  for (const key of FLAG_KEYS) assert.equal(flags[key], false, key);
});

test('TC-DF006-03 every schemas/*.json file is valid JSON (same scope as `jq empty schemas/*.json`)', () => {
  const files = readdirSync(SCHEMAS_DIR).filter((f) => f.endsWith('.json'));
  for (const name of DOCUMENT_SCHEMAS) assert.ok(files.includes(`${name}.schema.json`), name);
  for (const file of files) assert.doesNotThrow(() => readJsonFile(path.join(SCHEMAS_DIR, file)), file);
});

// ---------------------------------------------------------------------------------------------
// Drift guards: hand-written enums and ranges must equal contracts/*.v1.json
// ---------------------------------------------------------------------------------------------

test('AC-DF-006.3 $defs named after a vocab enum equal contracts/vocab.v1.json values', () => {
  const vocab = readContract('vocab.v1.json').enums;
  let compared = 0;
  for (const name of DOCUMENT_SCHEMAS) {
    for (const [key, def] of Object.entries(SCHEMAS[name].$defs ?? {})) {
      if (!vocab[key]) continue;
      assert.ok(Array.isArray(def.enum), `${name}: $defs/${key} must be an enum`);
      assert.deepEqual(def.enum, vocab[key].values, `${name}: $defs/${key}`);
      compared += 1;
    }
  }
  assert.ok(compared >= 20, `expected the shared vocab enums to be compared, got ${compared}`);
});

test('AC-DF-006.3 inline sourceGrade / side / status subsets stay inside the vocab', () => {
  const vocab = readContract('vocab.v1.json').enums;
  const subsets = [
    ['posture-assessment', '/$defs/metric/properties/sourceGrade', 'sourceGrade'],
    ['circumference-measurement', '/properties/sourceGrade', 'sourceGrade'],
    ['circumference-measurement', '/properties/side', 'side'],
    ['member-summary', '/$defs/highlight/properties/sourceGrade/allOf/1/not', 'sourceGrade'],
    ['soap-note-v2', '/$defs/metricRow/allOf/0/then/properties/side', 'side'],
    ['soap-note-v2', '/$defs/metricRow/allOf/1/then/properties/side', 'side'],
  ];
  for (const [name, pointer, vocabKey] of subsets) {
    const found = collectEnums(SCHEMAS[name]).find((e) => e.pointer === pointer);
    assert.ok(found, `${name}${pointer}: enum not found`);
    for (const v of found.values) assert.ok(vocab[vocabKey].values.includes(v), `${name}${pointer}: ${v}`);
  }
});

test('AC-DF-006.4 numeric bounds equal contracts/metric-catalog.v1.json ranges', () => {
  const catalog = Object.fromEntries(readContract('metric-catalog.v1.json').metrics.map((m) => [m.metricCode, m]));
  const bounds = (def) => ({
    min: def.minimum ?? def.exclusiveMinimum,
    minExclusive: def.exclusiveMinimum !== undefined,
    max: def.maximum,
  });
  const expectRange = (code, def) => {
    const { min, minExclusive, max } = catalog[code].range;
    assert.deepEqual(bounds(def), { min, minExclusive, max }, code);
  };
  const bc = SCHEMAS['body-composition-record'];
  for (const [key, def] of Object.entries(bc.properties.values.properties)) expectRange(key, def);
  expectRange('bmi', bc.properties.derived.oneOf[0].properties.bmi);
  const valueCm = SCHEMAS['circumference-measurement'].properties.valueCm;
  for (const m of Object.values(catalog).filter((x) => x.family === 'circumference')) expectRange(m.metricCode, valueCm);
  const soap = SCHEMAS['soap-note-v2'];
  expectRange('painNrs', soap.properties.subjective.properties.painNrs.oneOf[0].allOf[1].properties.$int);
  expectRange('mmtGrade', soap.$defs.metricRow.allOf[1].then.properties.value.allOf[1].properties.$int);
});

// ---------------------------------------------------------------------------------------------
// soap-note-v2 — §9.3 field rules beyond the card table
// ---------------------------------------------------------------------------------------------

const SOAP_VARIANTS = [
  ['quickNote over 1000 chars', 'finalized_no_metrics', (d) => { d.quickNote = 'a'.repeat(1001); }, 'maxLength'],
  ['chiefComplaint over 2000 chars', 'draft_rom_mmt_pain', (d) => { d.subjective.chiefComplaint = 'a'.repeat(2001); }, 'maxLength'],
  ['memberNote over 200 chars', 'refs_snapshots_pending_policy', (d) => { d.memberNote = 'a'.repeat(201); }, 'maxLength'],
  ['61 metrics', 'draft_rom_mmt_pain', (d) => { d.objective.metrics = Array(61).fill(d.objective.metrics[0]); }, 'maxItems'],
  ['61 snapshots', 'refs_snapshots_pending_policy', (d) => { d.objective.snapshots = Array(61).fill(d.objective.snapshots[0]); }, 'maxItems'],
  ['21 refs', 'refs_snapshots_pending_policy', (d) => { d.objective.refs.postureAssessmentIds = Array(21).fill('fx-posture-001'); }, 'maxItems'],
  ['65 painRegions', 'draft_rom_mmt_pain', (d) => { d.subjective.painRegions = Array(65).fill('neck'); }, 'maxItems'],
  ['painNrs 11', 'draft_rom_mmt_pain', (d) => { d.subjective.painNrs = INT(11); }],
  ['painNrs bare number (needs $int)', 'draft_rom_mmt_pain', (d) => { d.subjective.painNrs = 4; }],
  ['mmtGrade value bare number (needs $int)', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[1].value = 4; }],
  ['mmtGrade value 6', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[1].value = INT(6); }],
  ['mmtGrade without muscleGroup', 'draft_rom_mmt_pain', (d) => { delete d.objective.metrics[1].muscleGroup; }, 'required'],
  ['romDeg without joint', 'draft_rom_mmt_pain', (d) => { delete d.objective.metrics[0].joint; }, 'required'],
  ['romDeg with side none', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[0].side = 'none'; }],
  ['romDeg with unit 도', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[0].unit = '도'; }],
  ['metric value as string "110-120"', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[0].value = '110-120'; }],
  ['side 좌', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[0].side = '좌'; }],
  ['specialTestResult row (Q-14)', 'forward_compat_unknown_code', (d) => { d.objective.metrics[0].metricCode = 'specialTestResult'; }, 'not'],
  ['metric row with legacy label key', 'draft_rom_mmt_pain', (d) => { d.objective.metrics[0].label = '고관절 굴곡 ROM'; }, 'additionalProperties'],
  ['snapshot changeStatus unknown', 'refs_snapshots_pending_policy', (d) => { d.objective.snapshots[0].changeStatus = 'improved'; }],
  ['snapshot without measuredAt', 'refs_snapshots_pending_policy', (d) => { delete d.objective.snapshots[0].measuredAt; }, 'required'],
  ['status 완료', 'finalized_no_metrics', (d) => { d.status = '완료'; }],
  ['schemaVersion 1', 'finalized_no_metrics', (d) => { d.schemaVersion = 1; }, 'const'],
  ['legalNature other', 'finalized_no_metrics', (d) => { d.legalNature = 'medicalRecord'; }, 'const'],
  ['finalized without finalizedAt', 'finalized_no_metrics', (d) => { delete d.finalizedAt; }, 'required'],
  ['finalized with blank nextSession', 'finalized_no_metrics', (d) => { d.plan.nextSession = '  '; }, 'pattern'],
  ['finalized without plan', 'finalized_no_metrics', (d) => { delete d.plan; }, 'required'],
  ['no member key', 'pending_member_draft', (d) => { d.pendingMemberId = null; }],
  ['pending draft with memberId', 'pending_member_draft', (d) => { d.memberId = 'fx-pending-001'; }, 'not'],
  ['inline drawingData', 'finalized_no_metrics', (d) => { d.drawingData = { $bytes: 'AAAA' }; }, 'additionalProperties'],
  ['inkPath outside soapInk/', 'pending_member_draft', (d) => { d.inkPath = 'drawings/fx-note-v2-003.drawing'; }],
  ['inkRevision 0', 'pending_member_draft', (d) => { d.inkRevision = INT(0); }],
  ['sessionDate as millis', 'finalized_no_metrics', (d) => { d.sessionDate = 1790000000000; }],
  ['sessionDate $ts without offset', 'finalized_no_metrics', (d) => { d.sessionDate = TS('2026-09-28 01:00:00'); }],
  ['unknown tag $timestamp', 'finalized_no_metrics', (d) => { d.createdAt = { $timestamp: '2026-09-28T01:00:05Z' }; }],
  ['subjective extra key', 'draft_rom_mmt_pain', (d) => { d.subjective.painNow = 4; }, 'additionalProperties'],
  ['exerciseAssessment 21 observations', 'refs_snapshots_pending_policy', (d) => { d.exerciseAssessment.observations = Array(21).fill('관찰'); }, 'maxItems'],
];

for (const [label, base, mutate, keyword] of SOAP_VARIANTS) {
  test(`AC-DF-006.3 soap-note-v2 rejects: ${label}`, () => {
    const data = v2Data(base);
    mutate(data);
    assertInvalid('soap-note-v2', data, label, keyword ? { keyword } : {});
  });
}

test('AC-DF-006.3 soap-note-v2 accepts a MIG-03 migrated finalized note with legacy raw data and blank nextSession', () => {
  const data = v2Data('finalized_no_metrics');
  data.plan.nextSession = '';
  data.migratedFrom = { runId: 'fx-mig03-run-001', schemaVersion: 1 };
  data.legacy = {
    metricsRaw: [{ type: 'ROM', label: '경추 굴곡', side: '양측', value: '40-45', unit: '도' }],
    diagnosisRaw: '(원문 보존, 표시 금지 영역)',
    originalIsShared: true,
    completedCategories: ['subjective', 'objective'],
  };
  data.memberSummaryId = null;
  assertValid('soap-note-v2', data, 'migrated');
});

test('AC-DF-006.3 soap-note-v2 accepts a promoted note that has both member keys', () => {
  const data = v2Data('draft_rom_mmt_pain');
  data.pendingMemberId = 'fx-pending-001';
  assertValid('soap-note-v2', data, 'promoted');
});

// ---------------------------------------------------------------------------------------------
// The other six schemas — sample passes, PRD §9.2 constraints fail
// ---------------------------------------------------------------------------------------------

for (const name of DOCUMENT_SCHEMAS.filter((n) => n !== 'soap-note-v2')) {
  test(`AC-DF-006.3 ${name}: the synthetic V1-05 example passes`, () => {
    assertValid(name, sample(name), `${name} sample`);
  });
}

const OTHER_VARIANTS = [
  ['soap-addendum', 'empty reason', (d) => { d.reason = ''; }, 'minLength'],
  ['soap-addendum', 'text over 4000 chars', (d) => { d.text = 'a'.repeat(4001); }, 'maxLength'],
  ['soap-addendum', '21 changedFields', (d) => { d.changedFields = Array(21).fill('plan.nextSession'); }, 'maxItems'],
  ['soap-addendum', 'extra key', (d) => { d.diagnosis = '합성'; }, 'additionalProperties'],
  ['posture-assessment', '4 views', (d) => { d.views = Array(4).fill(d.views[0]); }, 'maxItems'],
  ['posture-assessment', '31 metrics', (d) => { d.metrics = Array(31).fill(d.metrics[0]); }, 'maxItems'],
  ['posture-assessment', '33 landmarks', (d) => { d.views[0].landmarks = Array(33).fill(d.views[0].landmarks[1]); }, 'maxItems'],
  ['posture-assessment', 'landmark x 1.2', (d) => { d.views[0].landmarks[0].x = 1.2; }, 'maximum'],
  ['posture-assessment', 'unknown landmark code', (d) => { d.views[0].landmarks[1].code = 'noseTip'; }, 'enum'],
  ['posture-assessment', 'confirmed without metrics', (d) => { delete d.metrics; }, 'required'],
  ['posture-assessment', 'confirmed with empty metrics', (d) => { d.metrics = []; }, 'minItems'],
  ['posture-assessment', 'metric sourceGrade trainerObserved', (d) => { d.metrics[0].sourceGrade = 'trainerObserved'; }, 'enum'],
  ['posture-assessment', 'view back', (d) => { d.views[0].view = 'back'; }],
  ['posture-assessment', 'photoPath outside postureAssessments/', (d) => { d.views[0].photoPath = 'photos/fx.jpg'; }],
  ['posture-assessment', 'captureConditions missing pitchDeg', (d) => { delete d.captureConditions.pitchDeg; }, 'required'],
  ['posture-assessment', 'schemaVersion 2', (d) => { d.schemaVersion = 2; }, 'const'],
  ['body-composition-record', 'source other', (d) => { d.source = 'csvImport'; }],
  ['body-composition-record', 'bodyFatPercent 101', (d) => { d.values = { bodyFatPercent: 101 }; }, 'maximum'],
  ['body-composition-record', 'segmentalLeanMassKg in values (v2)', (d) => { d.values.segmentalLeanMassKg = 20; }, 'additionalProperties'],
  ['body-composition-record', 'sourceGrade tape', (d) => { d.sourceGrade = 'tape'; }, 'const'],
  ['body-composition-record', 'deviceModel empty', (d) => { d.deviceModel = ''; }, 'minLength'],
  ['body-composition-record', 'voided without voidReason', (d) => { d.status = 'voided'; d.voidedAt = SERVER_TS; }, 'required'],
  ['body-composition-record', 'derived heightCmUsed 90', (d) => { d.derived.heightCmUsed = 90; }],
  ['body-composition-record', 'no member key', (d) => { d.pendingMemberId = null; }],
  ['circumference-measurement', 'custom without landmarkNote', (d) => { d.landmarkNote = null; }],
  ['circumference-measurement', 'side bilateral', (d) => { d.side = 'bilateral'; }, 'enum'],
  ['circumference-measurement', 'valueCm 0', (d) => { d.valueCm = 0; }, 'minimum'],
  ['circumference-measurement', 'trialIndex bare number', (d) => { d.trialIndex = 2; }],
  ['circumference-measurement', 'trialIndex 4', (d) => { d.trialIndex = INT(4); }],
  ['circumference-measurement', 'observedSection without scanId', (d) => { d.sourceGrade = 'observedSection'; d.isBeta = true; d.validationStatus = 'unvalidated'; }],
  ['circumference-measurement', 'observedSection not beta', (d) => { Object.assign(d, { sourceGrade: 'observedSection', scanId: 'fx-scan-001', isBeta: false, validationStatus: 'unvalidated' }); }, 'const'],
  ['circumference-measurement', 'observedSection for a pending member', (d) => { Object.assign(d, { memberUid: null, pendingMemberId: 'fx-pending-001', sourceGrade: 'observedSection', scanId: 'fx-scan-001', isBeta: true, validationStatus: 'unvalidated' }); }],
  ['circumference-measurement', 'tape marked beta', (d) => { d.isBeta = true; }, 'const'],
  ['member-summary', '11 highlights', (d) => { d.highlights = Array(11).fill(d.highlights[0]); }, 'maxItems'],
  ['member-summary', '7 sharedPhotoPaths', (d) => { d.sharedPhotoPaths = Array(7).fill(d.sharedPhotoPaths[0]); }, 'maxItems'],
  ['member-summary', 'original photo path shared', (d) => { d.sharedPhotoPaths = ['postureAssessments/fx-posture-001/sagittalLeft.jpg']; }, 'pattern'],
  ['member-summary', 'painNrs highlight', (d) => { d.highlights[0].metricCode = 'painNrs'; }, 'not'],
  ['member-summary', 'photoAuto highlight', (d) => { d.highlights[0].sourceGrade = 'photoAuto'; }, 'not'],
  ['member-summary', 'observedSection highlight', (d) => { d.highlights[0].sourceGrade = 'observedSection'; }, 'not'],
  ['member-summary', 'body over 8000 chars', (d) => { d.body = 'a'.repeat(8001); }, 'maxLength'],
  ['member-summary', 'title over 100 chars', (d) => { d.title = 'a'.repeat(101); }, 'maxLength'],
  ['member-summary', 'revoked but body kept', (d) => { Object.assign(d, { status: 'revoked', revokedAt: SERVER_TS, title: '', highlights: [], sharedPhotoPaths: [], nextPlan: '', sharedByDisplayName: null }); }, 'const'],
  ['member-summary', 'revoked without revokedAt', (d) => { Object.assign(d, { status: 'revoked', revokedAt: null, title: '', body: '', highlights: [], sharedPhotoPaths: [], nextPlan: '', sharedByDisplayName: null }); }],
  ['consent-record', 'neither subjectUid nor pendingMemberId', (d) => { d.pendingMemberId = null; }],
  ['consent-record', 'unknown consentType', (d) => { d.consentType = 'marketing'; }, 'enum'],
  ['consent-record', 'unknown channel', (d) => { d.channel = 'email'; }, 'enum'],
  ['consent-record', 'signature outside consentSignatures/', (d) => { d.signaturePath = 'signatures/fx.png'; }],
  ['consent-record', 'free-text reason field', (d) => { d.reason = '합성'; }, 'additionalProperties'],
];

for (const [name, label, mutate, keyword] of OTHER_VARIANTS) {
  test(`AC-DF-006.3 ${name} rejects: ${label}`, () => {
    const doc = sample(name);
    mutate(doc);
    assertInvalid(name, doc, label, keyword ? { keyword } : {});
  });
}

test('AC-DF-006.3 member-summary accepts a revoked tombstone with emptied content', () => {
  const doc = sample('member-summary');
  Object.assign(doc, {
    status: 'revoked',
    revokedAt: SERVER_TS,
    title: '',
    body: '',
    highlights: [],
    sharedPhotoPaths: [],
    nextPlan: '',
    sharedByDisplayName: null,
  });
  assertValid('member-summary', doc, 'tombstone');
});

test('AC-DF-006.3 circumference-measurement accepts an observedSection row with scanId', () => {
  const doc = sample('circumference-measurement');
  Object.assign(doc, {
    metricCode: 'waistCircumference',
    side: 'none',
    sourceGrade: 'observedSection',
    protocolId: 'waistMidpoint',
    landmarkNote: null,
    scanId: 'fx-scan-001',
    isBeta: true,
    validationStatus: 'unvalidated',
    trialIndex: INT(1),
  });
  assertValid('circumference-measurement', doc, 'observedSection');
});

// ---------------------------------------------------------------------------------------------
// TC-DF006-04 — docs/firestore_schema.md (AC-DF-006.1, AC-DF-006.2)
// ---------------------------------------------------------------------------------------------

const SCHEMA_DOC = path.join(REPO_ROOT, 'docs', 'firestore_schema.md');

// GitHub heading anchors (github-slugger rules: lower-case, drop punctuation, spaces → '-', -N for repeats).
function headingAnchors(markdown) {
  const seen = new Map();
  const anchors = new Set();
  let fenced = false;
  for (const line of markdown.split('\n')) {
    if (/^```/.test(line)) {
      fenced = !fenced;
      continue;
    }
    const m = fenced ? null : /^#{1,6}\s+(.*?)\s*$/.exec(line);
    if (!m) continue;
    const base = m[1]
      .toLowerCase()
      .replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, '')
      .replace(/ /g, '-');
    const n = seen.get(base) ?? 0;
    seen.set(base, n + 1);
    anchors.add(n ? `${base}-${n}` : base);
  }
  return anchors;
}

function headings(markdown) {
  return markdown
    .split('\n')
    .filter((l) => /^#{2,4}\s/.test(l))
    .map((l) => l.replace(/^#+\s*/, ''));
}

// Returns the text of the section that starts at the first heading matching `re`, up to the next heading of
// the same or a higher level.
function section(markdown, re) {
  const lines = markdown.split('\n');
  const start = lines.findIndex((l) => /^#{2,4}\s/.test(l) && re.test(l));
  assert.ok(start >= 0, `heading ${re} not found`);
  const level = /^#+/.exec(lines[start])[0].length;
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((l) => {
    const m = /^(#+)\s/.exec(l);
    return m && m[1].length <= level;
  });
  return lines.slice(start, end < 0 ? undefined : start + 1 + end).join('\n');
}

const COLLECTION_SECTIONS = [
  ['pendingMembers', 'pendingmemberspendingmemberid-신규'],
  ['postureAssessments', 'postureassessmentsassessmentid-신규'],
  ['bodyCompositionRecords', 'bodycompositionrecordsrecordid-신규'],
  ['circumferenceMeasurements', 'circumferencemeasurementsmeasurementid-신규'],
  ['bodyScans', 'bodyscansscanid-신규-lidarbeta-p2'],
  ['memberSummaries', 'membersummariessummaryid-신규-소비자본-서버-작성'],
  ['consentRecords', 'consentrecordsrecordid-신규-append-only-서버-작성'],
  ['memberConsentStates', 'memberconsentstatesmemberkey-신규-서버-파생'],
  ['consentDocumentVersions', 'consentdocumentversionsversionid-신규-관리자-서버-작성'],
  ['rightsRequests', 'rightsrequestsrequestid-신규-서버-작성'],
  ['opsMetrics', 'opsmetricsisoweek-신규-서버-전용'],
  ['appConfig/features', 'appconfigfeatures-기존-확장'],
];

test('TC-DF006-04 AC-DF-006.1 soap_notes has a v2 field table linked to PRD §9.3, an addenda section and a read-only legacy section', () => {
  const doc = readFileSync(SCHEMA_DOC, 'utf8');
  const soap = section(doc, /soap_notes\/\{noteId\}/);
  assert.match(soap, /\(PRD_V1\.md#필드-정본\)/, 'link to PRD §9.3 field table');
  const table = section(soap, /v2 필드 표/);
  for (const field of ['schemaVersion', 'authorUid', 'memberUid', 'sessionDate', 'quickNote', 'objective', 'legalNature', 'migratedFrom', 'legacy']) {
    assert.match(table, new RegExp(`\`${field}\``), `v2 table lists ${field}`);
  }
  const addenda = section(soap, /addenda/);
  assert.match(addenda, /\(PRD_V1\.md#soap_notesnoteidaddendaaddendumid\)/);
  assert.match(addenda, /schemas\/soap-addendum\.schema\.json/);
  const legacy = section(soap, /레거시\(v1\) 읽기 전용/);
  assert.match(legacy, /쓰기 금지\(MIG-03 적용 시\)/);
  for (const moved of ['structured', 'isSharedWithMember', 'drawingData', '"side": "좌"']) assert.ok(legacy.includes(moved), `legacy keeps ${moved}`);
});

test('TC-DF006-04 AC-DF-006.1 change procedure step 3 points at the shared fixtures, Dart and Swift test paths', () => {
  const doc = readFileSync(SCHEMA_DOC, 'utf8');
  const procedure = section(doc, /^## 변경 절차/);
  const step3 = /^3\. [\s\S]*?(?=^4\. )/m.exec(procedure)?.[0] ?? '';
  for (const p of ['contracts/fixtures/soap_*', 'test/contracts/', 'trainer_app/Packages/TrainerCore/Tests/TrainerDomainTests/']) {
    assert.ok(step3.includes(p), `step 3 mentions ${p}`);
  }
  assert.doesNotMatch(procedure, /SoapNoteFirestoreCompatTests/);
});

test('TC-DF006-04 AC-DF-006.2 the §9.2 collections each have a section linked to the PRD table with a one-line field list', () => {
  const doc = readFileSync(SCHEMA_DOC, 'utf8');
  const toc = section(doc, /^## 목차/);
  const titles = headings(doc);
  for (const [collection, anchor] of COLLECTION_SECTIONS) {
    const title = titles.find((t) => t.startsWith(`\`${collection}`));
    assert.ok(title, `section for ${collection}`);
    assert.ok(toc.includes(`\`${collection}`), `table of contents lists ${collection}`);
    const body = section(doc, new RegExp(`^## \`${collection.replace('/', '\\/')}`));
    assert.ok(body.includes(`(PRD_V1.md#${anchor})`), `${collection} links PRD §9.2 #${anchor}`);
    assert.match(body, /^- 필드[^\n]*: .+/m, `${collection} has a one-line field summary`);
  }
  const flags = section(doc, /^## `appConfig\/features`/);
  assert.match(titles.find((t) => t.startsWith('`appConfig/features`')), /8키/);
  for (const key of FLAG_KEYS) assert.ok(flags.includes(`\`${key}\``), `appConfig/features lists ${key}`);
});

test('TC-DF006-04 every PRD, V1-05 and in-page anchor in firestore_schema.md resolves to a heading', () => {
  const doc = readFileSync(SCHEMA_DOC, 'utf8');
  const targets = {
    'PRD_V1.md': headingAnchors(readFileSync(path.join(REPO_ROOT, 'docs', 'PRD_V1.md'), 'utf8')),
    'v1/05_DATA_MODEL_AND_RULES.md': headingAnchors(
      readFileSync(path.join(REPO_ROOT, 'docs', 'v1', '05_DATA_MODEL_AND_RULES.md'), 'utf8'),
    ),
    '': headingAnchors(doc),
  };
  const links = [...doc.matchAll(/\]\(([^)#\s]*)#([^)\s]+)\)/g)];
  assert.ok(links.length >= 30, `expected many anchored links, got ${links.length}`);
  for (const [, file, anchor] of links) {
    assert.ok(file in targets, `unexpected anchored link target ${file}#${anchor}`);
    assert.ok(targets[file].has(decodeURIComponent(anchor)), `broken anchor ${file}#${anchor}`);
  }
});
