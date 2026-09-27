// DF-035 기능 플래그 규칙: R-22(lidarBeta), R-29(bodyComposition). V1-05 §7.7, ADR-010.
// 플래그 말고는 create 조건을 모두 만족시켜, 거부가 플래그 때문임을 대조군으로 증명한다. 모든 값은 합성이다.
const assert = require('node:assert/strict');
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, serverTimestamp, setDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, member1} = h.IDS;
let env;
let seq = 0;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-flags'});
});

after(async () => {
  await env.cleanup();
});

// 담당 A, member1 동의 ② ③
async function seedBase(flags) {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedConsent(member1, {healthData: true, bodyImaging: true}),
    ...h.seedFlags(flags),
  });
}

function createCirc(payload) {
  seq += 1;
  return setDoc(doc(h.trainerDb(env), `circumferenceMeasurements/fx-circ-${seq}`), payload);
}

beforeEach(async () => {
  await env.clearFirestore();
});

describe('lidarBeta (R-22)', () => {
  test('R-22 control: observedSection circumference is allowed when lidarBeta=true', async () => {
    await seedBase({lidarBeta: true});
    await assertSucceeds(createCirc(h.observedSectionDoc()));
  });

  test('R-22 observedSection circumference with every other condition met is denied when lidarBeta=false', async () => {
    await seedBase({lidarBeta: false});
    await assertFails(createCirc(h.observedSectionDoc()));
  });

  // bodyScans는 P2 전이라 규칙 블록이 없다. 지금의 거부는 플래그가 아니라 기본 거부다.
  // P2가 블록을 추가하면 아래 첫 테스트가 실패해, 플래그만 끈 격리 테스트로 바꾸게 한다.
  test('R-22 bodyScans has no rule block yet (tripwire: P2 must replace these with a flag-isolated test)', () => {
    assert.ok(!/match \/bodyScans\//.test(h.readRulesText()), 'bodyScans block added: write the R-22 flag test');
  });

  test('R-22 bodyScans create and read are denied by the default deny with lidarBeta=false and =true', async () => {
    for (const lidarBeta of [false, true]) {
      await seedBase({lidarBeta});
      await assertFails(setDoc(doc(h.trainerDb(env), `bodyScans/fx-scan-${lidarBeta}`), {
        ...h.rawRecordDoc('bodyScans'), createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      }));
      await h.seed(env, {'bodyScans/fx-scan-stored': h.rawRecordDoc('bodyScans')});
      await assertFails(getDoc(doc(h.trainerDb(env), 'bodyScans/fx-scan-stored')));
    }
  });
});

describe('bodyComposition (R-29)', () => {
  test('R-29 control: tape circumference is allowed when bodyComposition=true', async () => {
    await seedBase({bodyComposition: true});
    await assertSucceeds(createCirc(h.tapeDoc()));
  });

  test('R-29 tape circumference is denied when bodyComposition=false', async () => {
    await seedBase({bodyComposition: false});
    await assertFails(createCirc(h.tapeDoc()));
  });

  test('R-29 tape circumference is denied when appConfig/features has no bodyComposition key', async () => {
    await seedBase({});
    await h.seed(env, {'appConfig/features': {soapV2: true, bodyAssessment: true, lidarBeta: false}});
    await assertFails(createCirc(h.tapeDoc()));
  });
});
