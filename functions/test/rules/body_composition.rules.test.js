// DF-035 신체조성 규칙: R-14, R-17, R-27과 AC-DF-035.2 경계값(TC-DF035-90~96). V1-05 §7.6.
// 대조군 create가 통과하는 상태에서 조건 하나만 바꿔 거부 원인을 하나로 좁힌다. 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, member1} = h.IDS;
let env;
let seq = 0;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-body-composition'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// 담당 A, member1 동의 ②, bodyComposition=true
async function seedBase({consent = {healthData: true}} = {}) {
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...(consent ? h.seedConsent(member1, consent) : {}),
    ...h.seedFlags({bodyComposition: true}),
  });
}

function create(payload) {
  seq += 1;
  return setDoc(doc(h.trainerDb(env), `bodyCompositionRecords/fx-bc-${seq}`), payload);
}

describe('bodyCompositionRecords create: consent ② (R-14)', () => {
  test('R-14 control: assigned trainer with consent ② creates a manual entry', async () => {
    await seedBase();
    await assertSucceeds(create(h.bodyCompDoc()));
  });

  test('R-14 no memberConsentStates document for the member: create is denied', async () => {
    await seedBase({consent: null});
    await assertFails(create(h.bodyCompDoc()));
  });

  test('R-14 consent state exists but healthData is not granted: create is denied', async () => {
    await seedBase({consent: {healthData: false}});
    await assertFails(create(h.bodyCompDoc()));
  });
});

describe('bodyCompositionRecords create: value checks (R-17, R-27, AC-DF-035.2)', () => {
  beforeEach(async () => {
    await seedBase();
  });

  test('R-17 deviceModel "" is denied', async () => {
    await assertFails(create(h.bodyCompDoc({deviceModel: ''})));
  });

  test('R-17 weightKg 0 is denied (an unmeasured key is omitted, never 0)', async () => {
    await assertFails(create(h.bodyCompDoc({values: {weightKg: 0}})));
  });

  test('R-17 values {} is denied', async () => {
    await assertFails(create(h.bodyCompDoc({values: {}})));
  });

  test('R-27 values.bodyFatPercent 0 is allowed', async () => {
    await assertSucceeds(create(h.bodyCompDoc({values: {bodyFatPercent: 0}})));
  });

  test('R-27 TC-DF035-90 bodyFatPercent 0 with weight is allowed', async () => {
    await assertSucceeds(create(h.bodyCompDoc({values: {weightKg: 70.5, bodyFatPercent: 0}})));
  });

  test('R-17 TC-DF035-91 bodyFatPercent 100.1 is denied, 100 is allowed', async () => {
    await assertFails(create(h.bodyCompDoc({values: {bodyFatPercent: 100.1}})));
    await assertSucceeds(create(h.bodyCompDoc({values: {bodyFatPercent: 100}})));
  });

  test('R-17 TC-DF035-92 weightKg 0 is denied', async () => {
    await assertFails(create(h.bodyCompDoc({values: {weightKg: 0, bodyFatPercent: 22.4}})));
  });

  test('R-17 TC-DF035-93 weightKg -1 is denied', async () => {
    await assertFails(create(h.bodyCompDoc({values: {weightKg: -1, bodyFatPercent: 22.4}})));
  });

  test('R-17 TC-DF035-94 values {} is denied', async () => {
    await assertFails(create(h.bodyCompDoc({values: {}})));
  });

  test('R-17 TC-DF035-95 deviceModel "" is denied', async () => {
    await assertFails(create(h.bodyCompDoc({deviceModel: ''})));
  });

  test('R-17 TC-DF035-96 deviceModel of 65 characters is denied, 64 is allowed', async () => {
    await assertFails(create(h.bodyCompDoc({deviceModel: 'x'.repeat(65)})));
    await assertSucceeds(create(h.bodyCompDoc({deviceModel: 'x'.repeat(64)})));
  });
});
