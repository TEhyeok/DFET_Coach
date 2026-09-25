// TC-DF003-01: contracts/metric-catalog.v1.json
// Expected values are transcribed by hand from docs/v1/05_DATA_MODEL_AND_RULES.md §13.1
// (itself copied from docs/PRD_V1.md appendix A.1-A.2 and A.4). Do not derive them from the JSON.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readContract, duplicates } from './helpers.mjs';

const catalog = readContract('metric-catalog.v1.json');
const vocab = readContract('vocab.v1.json');

// Condition-key abbreviations from the §13.1 table.
const P = ['protocolVersion', 'view', 'captureConditions.clothing', 'stationProfile', 'device.model'];
const B = ['deviceModel', 'fasting', 'timeOfDayBand'];
const C = ['sourceGrade', 'protocolId', 'protocolVersion'];
const C_SIDE = [...C, 'side'];
const PHOTO = ['photoManual', 'photoAuto'];
const POSTURE = { collection: 'postureAssessments', field: 'metrics' };
const bc = (field) => ({ collection: 'bodyCompositionRecords', field });
const CIRC = { collection: 'circumferenceMeasurements', field: 'valueCm' };
const r = (min, minExclusive, max, appMin) => ({ min, minExclusive, max, appMin });
const CIRC_RANGE = r(1, false, 400, 1);

// [metricCode, nameKo, family, unit, decimals, scale, sideRule,
//  allowed, screeningOnly, beta, tier, direction, conditionKeys, availability, judgeAs, storage, range]
const EXPECTED = [
  ['craniovertebralAngle', '두개척추각(CVA)', 'posture', 'deg', 1, 'ratio', 'none', PHOTO, ['photoAuto'], [], 'tier1', 'higherIsBetter', P, 'v1', null, POSTURE, null],
  ['headTiltFrontal', '머리 기울기(정면, 참고)', 'posture', 'deg', 1, 'ratio', 'magnitudeWithLowerSide', PHOTO, ['photoAuto'], [], 'reference', 'towardZero', P, 'v1Reference', null, POSTURE, null],
  ['shoulderTiltAngle', '어깨 높이차(견봉선 기울기각)', 'posture', 'deg', 1, 'ratio', 'magnitudeWithHigherSide', PHOTO, ['photoAuto'], [], 'tier1', 'towardZero', P, 'v1', null, POSTURE, null],
  ['pelvicTiltFrontal', '골반 기울기(정면, 참고)', 'posture', 'deg', 1, 'ratio', 'magnitudeWithHigherSide', PHOTO, ['photoAuto'], [], 'reference', 'towardZero', P, 'v1ReferenceDefaultOff', null, POSTURE, null],
  ['weightKg', '체중', 'bodyComposition', 'kg', 1, 'ratio', 'none', ['device'], [], [], null, 'none', B, 'v1', null, bc('values.weightKg'), r(0, true, 600, 0.1)],
  ['bodyFatPercent', '체지방률', 'bodyComposition', 'percent', 1, 'ratio', 'none', ['device'], [], [], null, 'none', B, 'v1', null, bc('values.bodyFatPercent'), r(0, false, 100, 0)],
  ['skeletalMuscleMassKg', '골격근량', 'bodyComposition', 'kg', 1, 'ratio', 'none', ['device'], [], [], null, 'higherIsBetter', B, 'v1', null, bc('values.skeletalMuscleMassKg'), r(0, true, 300, 0.1)],
  ['bodyFatMassKg', '체지방량', 'bodyComposition', 'kg', 1, 'ratio', 'none', ['device'], [], [], null, 'none', B, 'v1', null, bc('values.bodyFatMassKg'), r(0, true, 600, 0.1)],
  ['bmi', '체질량지수', 'bodyComposition', 'kgPerM2', 1, 'ratio', 'none', ['derived'], [], [], null, 'none', B, 'v1', 'weightKg', bc('derived.bmi'), r(0, true, 200, 0.1)],
  ['visceralFatLevel', '내장지방 레벨', 'bodyComposition', 'level', 1, 'ratio', 'none', ['device'], [], [], null, 'none', B, 'v1Optional', null, bc('values.visceralFatLevel'), r(0, true, 100, 1)],
  ['totalBodyWaterL', '체수분', 'bodyComposition', 'liter', 1, 'ratio', 'none', ['device'], [], [], null, 'none', B, 'v1Optional', null, bc('values.totalBodyWaterL'), r(0, true, 300, 0.1)],
  ['segmentalLeanMassKg', '부위별 근육량', 'bodyComposition', 'kg', 1, 'ratio', 'undefinedV2', ['device'], [], [], null, 'none', B, 'v2', null, bc('values.segmentalLeanMassKg'), null],
  ['phaseAngleDeg', '위상각', 'bodyComposition', 'deg', 1, 'ratio', 'none', ['device'], [], [], null, 'none', B, 'v2', null, bc('values.phaseAngleDeg'), null],
  ['waistCircumference', '허리둘레', 'circumference', 'cm', 1, 'ratio', 'none', ['tape', 'observedSection'], [], ['observedSection'], null, 'none', C, 'v1', null, CIRC, CIRC_RANGE],
  ['hipCircumference', '엉덩이둘레', 'circumference', 'cm', 1, 'ratio', 'none', ['tape', 'observedSection'], [], ['observedSection'], null, 'none', C, 'v1', null, CIRC, CIRC_RANGE],
  ['thighCircumference', '허벅지 둘레', 'circumference', 'cm', 1, 'ratio', 'leftRight', ['tape'], [], [], null, 'none', C_SIDE, 'v1', null, CIRC, CIRC_RANGE],
  ['upperArmCircumference', '상완 둘레', 'circumference', 'cm', 1, 'ratio', 'leftRight', ['tape'], [], [], null, 'none', C_SIDE, 'v1', null, CIRC, CIRC_RANGE],
  ['calfCircumference', '종아리 둘레', 'circumference', 'cm', 1, 'ratio', 'leftRight', ['tape'], [], [], null, 'none', C_SIDE, 'v1', null, CIRC, CIRC_RANGE],
  ['chestCircumference', '가슴둘레', 'circumference', 'cm', 1, 'ratio', 'none', ['tape'], [], [], null, 'none', C, 'v1', null, CIRC, CIRC_RANGE],
  ['painNrs', '통증 NRS', 'pain', 'point', 0, 'ratio', 'none', ['selfReport'], [], [], 'reference', 'lowerIsBetter', ['nrsScale'], 'v1', null, { collection: 'soap_notes', field: 'subjective.painNrs' }, r(0, false, 10, 0)],
  ['romDeg', '관절가동범위', 'trainerObservation', 'deg', 0, 'ratio', 'leftRightBilateral', ['trainerObserved'], [], [], null, 'higherIsBetter', ['joint', 'motion', 'activeOrPassive'], 'v1', null, { collection: 'soap_notes', field: 'objective.metrics' }, null],
  ['mmtGrade', '근력 등급(MMT 0–5)', 'trainerObservation', 'grade', 0, 'ordinal', 'leftRightBilateral', ['trainerObserved'], [], [], null, 'higherIsBetter', ['muscleGroup', 'side'], 'v1', null, { collection: 'soap_notes', field: 'objective.metrics' }, r(0, false, 5, 0)],
];

const FIELDS = [
  'metricCode', 'nameKo', 'family', 'unit', 'decimals', 'scale', 'sideRule',
  'allowedSourceGrades', 'screeningOnlySourceGrades', 'betaSourceGrades',
  'reliabilityTier', 'improvementDirection', 'conditionKeys', 'availability',
  'judgeAs', 'storage', 'range',
];

// §13.1 "조건 키 토큰" table.
const CONDITION_KEY_TOKENS = new Set([
  'protocolVersion', 'protocolId', 'view', 'captureConditions.clothing', 'stationProfile',
  'device.model', 'deviceModel', 'fasting', 'timeOfDayBand', 'sourceGrade', 'side',
  'algorithmVersion', 'joint', 'motion', 'activeOrPassive', 'muscleGroup', 'nrsScale',
]);

const EXCLUDED = ['kneeFppaSingleLegSquat', 'headForwardDistance', 'specialTestResult'];

const vocabValues = (name) => vocab.enums[name].values;

test('AC-DF-003.1 top-level shape: contract, version, revision, source, metrics, excludedMetricCodes', () => {
  assert.deepEqual(Object.keys(catalog), ['contract', 'version', 'revision', 'source', 'metrics', 'excludedMetricCodes']);
  assert.equal(catalog.contract, 'metric-catalog');
  assert.equal(catalog.version, 1);
  assert.ok(Number.isInteger(catalog.revision) && catalog.revision >= 1, 'revision is a positive integer');
  assert.match(catalog.source, /^[\x20-\x7E]+$/, 'source is ASCII');
  assert.match(catalog.source, /appendix A\.1-A\.2/);
});

test('AC-DF-003.1 all 22 appendix A.1 metricCodes are present in PRD table order', () => {
  assert.equal(catalog.metrics.length, 22);
  assert.deepEqual(catalog.metrics.map((m) => m.metricCode), EXPECTED.map((row) => row[0]));
});

test('AC-DF-003.1 every metric has exactly the V1-05 §13.1 field set, in order', () => {
  for (const metric of catalog.metrics) {
    assert.deepEqual(Object.keys(metric), FIELDS, `${metric.metricCode} fields`);
  }
});

test('AC-DF-003.1 field values match the V1-05 §13.1 table (22 rows + range table)', () => {
  for (const row of EXPECTED) {
    const expected = Object.fromEntries(FIELDS.map((field, i) => [field, row[i]]));
    const actual = catalog.metrics.find((m) => m.metricCode === row[0]);
    assert.deepEqual(actual, expected, `${row[0]} matches §13.1`);
  }
});

test('AC-DF-003.1 field types and cross-references to vocab are valid', () => {
  const codes = new Set(catalog.metrics.map((m) => m.metricCode));
  for (const m of catalog.metrics) {
    const at = m.metricCode;
    assert.equal(typeof m.nameKo, 'string', `${at}.nameKo`);
    assert.ok(m.nameKo.length > 0, `${at}.nameKo non-empty`);
    assert.ok(vocabValues('family').includes(m.family), `${at}.family ∈ vocab.family`);
    assert.ok(vocabValues('unit').includes(m.unit), `${at}.unit ∈ vocab.unit`);
    assert.ok(Number.isInteger(m.decimals) && m.decimals >= 0, `${at}.decimals int`);
    assert.ok(vocabValues('scale').includes(m.scale), `${at}.scale ∈ vocab.scale`);
    assert.ok(vocabValues('sideRule').includes(m.sideRule), `${at}.sideRule ∈ vocab.sideRule`);
    assert.ok(m.allowedSourceGrades.length >= 1, `${at}.allowedSourceGrades non-empty`);
    for (const g of m.allowedSourceGrades) assert.ok(vocabValues('sourceGrade').includes(g), `${at} allowed ${g} ∈ vocab.sourceGrade`);
    for (const g of m.screeningOnlySourceGrades) assert.ok(m.allowedSourceGrades.includes(g), `${at} screening ${g} ⊂ allowed`);
    for (const g of m.betaSourceGrades) assert.ok(m.allowedSourceGrades.includes(g), `${at} beta ${g} ⊂ allowed`);
    assert.ok(m.reliabilityTier === null || vocabValues('reliabilityTier').includes(m.reliabilityTier), `${at}.reliabilityTier`);
    assert.ok(vocabValues('improvementDirection').includes(m.improvementDirection), `${at}.improvementDirection`);
    for (const k of m.conditionKeys) assert.ok(CONDITION_KEY_TOKENS.has(k), `${at} conditionKey ${k} is a §13.1 token`);
    assert.equal(duplicates(m.conditionKeys).length, 0, `${at}.conditionKeys unique`);
    assert.ok(!m.conditionKeys.includes('algorithmVersion'), `${at}: algorithmVersion is not a catalog key (ASM-05-42)`);
    assert.ok(vocabValues('availability').includes(m.availability), `${at}.availability`);
    assert.ok(m.judgeAs === null || (codes.has(m.judgeAs) && m.judgeAs !== at), `${at}.judgeAs`);
    assert.deepEqual(Object.keys(m.storage), ['collection', 'field'], `${at}.storage shape`);
    if (m.range !== null) {
      assert.deepEqual(Object.keys(m.range), ['min', 'minExclusive', 'max', 'appMin'], `${at}.range shape`);
      assert.equal(typeof m.range.minExclusive, 'boolean');
      assert.ok(m.range.min <= m.range.appMin && m.range.appMin <= m.range.max, `${at}.range ordered`);
    }
  }
});

test('AC-DF-003.2 metricCode duplicates are 0', () => {
  assert.deepEqual(duplicates(catalog.metrics.map((m) => m.metricCode)), []);
});

test('AC-DF-003.2 appendix A.4 codes appear only in excludedMetricCodes', () => {
  assert.deepEqual(catalog.excludedMetricCodes, EXCLUDED);
  const codes = catalog.metrics.map((m) => m.metricCode);
  for (const code of EXCLUDED) {
    assert.ok(!codes.includes(code), `${code} must not be in metrics`);
    for (const m of catalog.metrics) assert.notEqual(m.judgeAs, code);
  }
});
