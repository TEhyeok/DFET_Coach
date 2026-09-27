// DF-035 체형 평가 규칙: R-15, R-16과 MVP 체형 문서 모양(DEC-22, DF-203 MVP 조각). V1-05 §7.5.
// 동의 ② healthData, ③ bodyImaging, ⑤ research. 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA} = h.IDS;
const ALL = 'member1'; // ② ③ ⑤
const HEALTH_ONLY = 'memberHealthOnly'; // ②만
const IMAGING_ONLY = 'memberImagingOnly'; // ③만
const NO_RESEARCH = 'memberNoResearch'; // ② ③, ⑤ 없음
let env;
let seq = 0;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-posture'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [ALL, HEALTH_ONLY, IMAGING_ONLY, NO_RESEARCH]),
    ...h.seedConsent(ALL, {healthData: true, bodyImaging: true, research: true}),
    ...h.seedConsent(HEALTH_ONLY, {healthData: true}),
    ...h.seedConsent(IMAGING_ONLY, {bodyImaging: true}),
    ...h.seedConsent(NO_RESEARCH, {healthData: true, bodyImaging: true, research: false}),
    ...h.seedFlags({bodyAssessment: true}),
  });
});

function create(payload) {
  seq += 1;
  return setDoc(doc(h.trainerDb(env), `postureAssessments/fx-posture-${seq}`), payload);
}

describe('postureAssessments create needs consent ② and ③ (R-15)', () => {
  test('R-15 control: member with ② ③ ⑤ is allowed', async () => {
    await assertSucceeds(create(h.postureDoc({memberUid: ALL})));
  });

  test('R-15 member with ② only is denied', async () => {
    await assertFails(create(h.postureDoc({memberUid: HEALTH_ONLY})));
  });

  test('R-15 member with ③ only is denied', async () => {
    await assertFails(create(h.postureDoc({memberUid: IMAGING_ONLY})));
  });
});

describe('postureAssessments retestGroupId needs research consent ⑤ (R-16)', () => {
  test('R-16 control: ② ③ without ⑤ and without retestGroupId is allowed', async () => {
    await assertSucceeds(create(h.postureDoc({memberUid: NO_RESEARCH})));
  });

  test('R-16 control: ② ③ ⑤ with retestGroupId is allowed', async () => {
    await assertSucceeds(create(h.postureDoc({memberUid: ALL, retestGroupId: 'fx-retest-001'})));
  });

  test('R-16 ② ③ without ⑤ and with retestGroupId is denied', async () => {
    await assertFails(create(h.postureDoc({memberUid: NO_RESEARCH, retestGroupId: 'fx-retest-001'})));
  });
});

describe('MVP posture document shape (DEC-22, DF-203 MVP slice)', () => {
  test('R-15 MVP shape (default-v1, three false checklist booleans, no levelDeg/pitchDeg, imageRotationDeg 0) is allowed', async () => {
    const payload = h.postureDoc({memberUid: ALL});
    // 모양 자체를 확인한다: 생성기가 바뀌어 MVP 모양이 아니게 되면 이 사례가 의미를 잃는다.
    const {captureConditions: c, views, landmarkEngine, stationProfileId} = payload;
    if (stationProfileId !== 'default-v1' || c.barefoot !== false || c.markersPlaced !== false || c.verbalConsentCheck !== false
      || 'levelDeg' in c || 'pitchDeg' in c || views.length !== 2 || views.some((v) => v.imageRotationDeg !== 0)
      || landmarkEngine.name !== 'appleVision2D' || landmarkEngine.version !== 'iOS17.4-r1') {
      throw new Error('postureDoc() is no longer the MVP shape');
    }
    await assertSucceeds(create(payload));
  });

  test('R-15 the same MVP shape without landmarkEngine is denied', async () => {
    await assertFails(create(h.withoutKeys(h.postureDoc({memberUid: ALL}), 'landmarkEngine')));
  });
});
