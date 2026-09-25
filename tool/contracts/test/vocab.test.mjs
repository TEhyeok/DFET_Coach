// TC-DF003-02: contracts/vocab.v1.json
// Expected names, counts, statuses and values are transcribed by hand from
// docs/v1/05_DATA_MODEL_AND_RULES.md §6.1, §6.4, §6.5, §13.2 and docs/PRD_V1.md appendix A.3-A.7, B.
// Do not derive them from the JSON.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readContract, duplicates } from './helpers.mjs';

const vocab = readContract('vocab.v1.json');

// [name, values, status, confirmBy, labelsKo required (● in §13.2)] — §13.2 table order.
const EXPECTED = [
  ['sourceGrade', ['tape', 'device', 'photoManual', 'photoAuto', 'observedSection', 'modelEstimate', 'aiAppearance', 'selfReport', 'trainerObserved', 'derived'], 'confirmed', null, true],
  ['reliabilityTier', ['tier1', 'reference', 'beta'], 'confirmed', null, true],
  ['changeStatus', ['meaningfulImprovement', 'withinError', 'meaningfulDecline', 'indeterminate', 'pendingPolicy'], 'confirmed', null, true],
  ['reasonCode', ['conditionMismatch', 'deviceChanged', 'protocolChanged', 'noMdc', 'noComparison', 'referenceMetric', 'betaMetric'], 'confirmed', null, true],
  ['mdcSource', ['literature', 'inHouse'], 'confirmed', null, true],
  ['improvementDirection', ['higherIsBetter', 'lowerIsBetter', 'towardZero', 'none'], 'confirmed', null, false],
  ['side', ['none', 'left', 'right', 'bilateral'], 'confirmed', null, true],
  ['syncState', ['localSaved', 'syncing', 'synced', 'syncFailed', 'awaitingConsent'], 'confirmed', null, true],
  ['family', ['posture', 'bodyComposition', 'circumference', 'pain', 'trainerObservation'], 'confirmed', null, false],
  ['sideRule', ['none', 'leftRight', 'leftRightBilateral', 'magnitudeWithLowerSide', 'magnitudeWithHigherSide', 'undefinedV2'], 'confirmed', null, false],
  ['availability', ['v1', 'v1Reference', 'v1ReferenceDefaultOff', 'v1Optional', 'v2'], 'confirmed', null, false],
  ['scale', ['ratio', 'ordinal'], 'confirmed', null, false],
  ['unit', ['deg', 'kg', 'percent', 'kgPerM2', 'level', 'liter', 'cm', 'point', 'grade'], 'confirmed', null, true],
  ['consentType', ['required', 'healthData', 'bodyImaging', 'sharing', 'research'], 'confirmed', null, true],
  ['consentAction', ['grant', 'withdraw'], 'confirmed', null, true],
  ['consentChannel', ['memberApp', 'trainerDeviceInPerson'], 'confirmed', null, true],
  ['soapStatus', ['draft', 'finalized'], 'confirmed', null, true],
  ['postureStatus', ['draft', 'confirmed', 'voided'], 'confirmed', null, true],
  ['measurementStatus', ['active', 'voided'], 'confirmed', null, true],
  ['pendingMemberStatus', ['pending', 'promoted', 'cancelled', 'expired'], 'confirmed', null, true],
  ['summaryStatus', ['shared', 'revoked'], 'confirmed', null, true],
  ['postureView', ['front', 'sagittalLeft', 'sagittalRight'], 'confirmed', null, true],
  ['clothing', ['fitted', 'regular', 'unknown'], 'draft', 'DF-915', true],
  ['fasting', ['yes', 'no', 'unknown'], 'confirmed', null, true],
  ['timeOfDayBand', ['morning', 'midday', 'evening'], 'confirmed', null, true],
  ['bodyCompositionSource', ['manualEntry', 'inbodyApi', 'healthKit'], 'confirmed', null, false],
  ['circumferenceProtocolId', ['waistMidpoint', 'hipMaximum', 'custom'], 'confirmed', null, true],
  ['landmarkCode', ['tragusLeft', 'tragusRight', 'c7', 'earLeft', 'earRight', 'acromionLeft', 'acromionRight', 'asisLeft', 'asisRight'], 'confirmed', null, true],
  ['activeOrPassive', ['active', 'passive'], 'draft', 'DF-916', true],
  ['joint', ['cervicalSpine', 'thoracicSpine', 'lumbarSpine', 'shoulder', 'elbow', 'wrist', 'hip', 'knee', 'ankle'], 'draft', 'DF-916', true],
  ['motion', ['flexion', 'extension', 'abduction', 'adduction', 'horizontalAbduction', 'horizontalAdduction', 'internalRotation', 'externalRotation', 'lateralFlexion', 'rotation', 'dorsiflexion', 'plantarflexion', 'inversion', 'eversion'], 'draft', 'DF-916', true],
  ['muscleGroup', ['neckFlexors', 'neckExtensors', 'shoulderFlexors', 'shoulderAbductors', 'shoulderInternalRotators', 'shoulderExternalRotators', 'elbowFlexors', 'elbowExtensors', 'trunkFlexors', 'trunkExtensors', 'hipFlexors', 'hipExtensors', 'hipAbductors', 'hipAdductors', 'kneeExtensors', 'kneeFlexors', 'ankleDorsiflexors', 'anklePlantarflexors'], 'draft', 'DF-916', true],
  ['regionCode', ['head', 'neck', 'shoulderLeft', 'shoulderRight', 'upperBack', 'lowerBack', 'chest', 'abdomen', 'elbowLeft', 'elbowRight', 'wristHandLeft', 'wristHandRight', 'hipLeft', 'hipRight', 'thighLeft', 'thighRight', 'kneeLeft', 'kneeRight', 'calfLeft', 'calfRight', 'ankleFootLeft', 'ankleFootRight'], 'draft', 'DF-916', true],
];

// Counts stated in AC-DF-003.3 and the §13.2 table (checked separately from the value lists above).
const EXPECTED_COUNTS = {
  sourceGrade: 10, reliabilityTier: 3, changeStatus: 5, reasonCode: 7, improvementDirection: 4,
  mdcSource: 2, consentType: 5, syncState: 5, side: 4, soapStatus: 2, fasting: 3, timeOfDayBand: 3,
  circumferenceProtocolId: 3, postureView: 3, landmarkCode: 9, regionCode: 22, joint: 9, motion: 14,
  muscleGroup: 18, unit: 9, family: 5, sideRule: 6, availability: 5, scale: 2, consentAction: 2,
  consentChannel: 2, postureStatus: 3, measurementStatus: 2, pendingMemberStatus: 4, summaryStatus: 2,
  clothing: 3, bodyCompositionSource: 3, activeOrPassive: 2,
};

const byName = new Map(EXPECTED.map((row) => [row[0], row]));

test('AC-DF-003.3 top-level shape: contract, version, revision, source, enums, jointMotionPairs', () => {
  assert.deepEqual(Object.keys(vocab), ['contract', 'version', 'revision', 'source', 'enums', 'jointMotionPairs']);
  assert.equal(vocab.contract, 'vocab');
  assert.equal(vocab.version, 1);
  assert.ok(Number.isInteger(vocab.revision) && vocab.revision >= 1);
  assert.match(vocab.source, /^[\x20-\x7E]+$/, 'source is ASCII');
});

test('AC-DF-003.3 exactly 33 enums with the §13.2 names in table order', () => {
  assert.equal(EXPECTED.length, 33);
  assert.equal(Object.keys(EXPECTED_COUNTS).length, 33);
  assert.deepEqual(Object.keys(vocab.enums), EXPECTED.map((row) => row[0]));
});

test('AC-DF-003.3 enum value counts match AC-DF-003.3 and the §13.2 table', () => {
  for (const [name, count] of Object.entries(EXPECTED_COUNTS)) {
    assert.equal(byName.get(name)[1].length, count, `expected table ${name}`);
    assert.equal(vocab.enums[name].values.length, count, `${name} has ${count} values`);
  }
});

test('AC-DF-003.3 enum values equal appendix A/B English codes character for character', () => {
  for (const [name, values] of EXPECTED) {
    assert.deepEqual(vocab.enums[name].values, values, name);
    assert.deepEqual(duplicates(vocab.enums[name].values), [], `${name} values unique`);
    for (const v of values) assert.match(v, /^[a-z][A-Za-z0-9]*$/, `${name}.${v} is ASCII camelCase`);
  }
});

test('AC-DF-003.3 enum object shape {status, confirmBy?, values, labelsKo?} and status per §13.2', () => {
  for (const [name, , status, confirmBy, labelsRequired] of EXPECTED) {
    const e = vocab.enums[name];
    const allowedKeys = ['status', 'confirmBy', 'values', 'labelsKo'];
    for (const key of Object.keys(e)) assert.ok(allowedKeys.includes(key), `${name} has unexpected key ${key}`);
    assert.equal(e.status, status, `${name}.status`);
    if (status === 'draft') assert.equal(e.confirmBy, confirmBy, `${name}.confirmBy`);
    else assert.ok(!('confirmBy' in e), `${name} is confirmed and must not carry confirmBy`);
    assert.equal('labelsKo' in e, labelsRequired, `${name}.labelsKo presence (● in §13.2)`);
  }
});

test('AC-DF-003.3 labelsKo covers every value exactly once, with non-empty strings', () => {
  for (const [name, e] of Object.entries(vocab.enums)) {
    if (!e.labelsKo) continue;
    assert.deepEqual(Object.keys(e.labelsKo), e.values, `${name}.labelsKo keys equal values in order`);
    for (const [k, label] of Object.entries(e.labelsKo)) {
      assert.equal(typeof label, 'string', `${name}.labelsKo.${k}`);
      assert.ok(label.trim().length > 0, `${name}.labelsKo.${k} non-empty`);
      assert.notEqual(label, '…', `${name}.labelsKo.${k} is not an ellipsis placeholder`);
    }
  }
});

test('AC-DF-003.3 unit labels match the §13.2 example', () => {
  assert.deepEqual(vocab.enums.unit.labelsKo, {
    deg: '°', kg: 'kg', percent: '%', kgPerM2: 'kg/m²', level: '레벨', liter: 'L', cm: 'cm', point: '점', grade: '등급',
  });
});

test('AC-DF-003.4 appendix A.5-A.7 blocks are draft with confirmBy DF-916', () => {
  for (const name of ['joint', 'motion', 'muscleGroup', 'regionCode', 'activeOrPassive']) {
    assert.equal(vocab.enums[name].status, 'draft', `${name}.status`);
    assert.equal(vocab.enums[name].confirmBy, 'DF-916', `${name}.confirmBy`);
  }
  assert.deepEqual(vocab.jointMotionPairs, { status: 'draft', confirmBy: 'DF-916', pairs: [] });
});
