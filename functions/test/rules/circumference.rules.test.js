// DF-035 둘레 규칙: R-26. 사용자 정의 프로토콜은 landmarkNote가 있어야 한다(AC-ASM-06.4, AC-ASM-06.5, V1-05 §7.7).
// 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, member1} = h.IDS;
let env;
let seq = 0;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-circumference'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedConsent(member1, {healthData: true}),
    ...h.seedFlags({bodyComposition: true}),
  });
});

function create(payload) {
  seq += 1;
  return setDoc(doc(h.trainerDb(env), `circumferenceMeasurements/fx-circ-${seq}`), payload);
}

describe('circumferenceMeasurements custom protocol (R-26)', () => {
  test('R-26 control: waistMidpoint protocol without landmarkNote is allowed', async () => {
    await assertSucceeds(create(h.tapeDoc()));
  });

  test("R-26 protocolId 'custom' without landmarkNote is denied", async () => {
    await assertFails(create(h.tapeDoc({protocolId: 'custom'})));
  });

  test("R-26 protocolId 'custom' with an empty landmarkNote is denied", async () => {
    await assertFails(create(h.tapeDoc({protocolId: 'custom', landmarkNote: ''})));
  });

  test("R-26 control: protocolId 'custom' with a landmarkNote is allowed", async () => {
    await assertSucceeds(create(h.tapeDoc({protocolId: 'custom', landmarkNote: '합성 기준점: 배꼽 위 2cm'})));
  });
});
