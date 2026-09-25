// DF-022 MIG-03 스위치: R-21 (V1-05 §9.2, AC-DF-022.3, MIG-03).
// 스위치 사본은 메모리에서만 만든다. firestore.rules 파일은 바꾸지 않는다.
const assert = require('node:assert/strict');
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {deleteDoc, doc, setDoc, updateDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1, member2} = h.IDS;
let closedEnv; // `// @mig03-switch` 줄을 return false;로 바꾼 사본
let openEnv; // 원본(스위치 true)

before(async () => {
  closedEnv = await h.initRulesEnv({
    projectId: 'dfet-rules-legacy-switch',
    rulesTransform: h.closeLegacySwitch,
  });
  openEnv = await h.initRulesEnv({projectId: 'dfet-rules-legacy-switch-original'});
});

after(async () => {
  await closedEnv.cleanup();
  await openEnv.cleanup();
});

async function seedS0(env, {soapV2}) {
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedTrainer(trainerB, [member2]),
    ...h.seedConsent(member1, {healthData: true}),
    ...h.seedFlags({soapV2}),
    'soap_notes/L1': h.v1SoapDoc(),
  });
}

beforeEach(async () => {
  await closedEnv.clearFirestore();
  await openEnv.clearFirestore();
});

describe('switch copy is made in memory only (AC-DF-022.3)', () => {
  test('R-21 the switched copy differs from firestore.rules in exactly the @mig03-switch line', () => {
    const original = h.readRulesText();
    const closed = h.closeLegacySwitch(original);
    const a = original.split('\n');
    const b = closed.split('\n');
    assert.equal(a.length, b.length);
    const diff = a.map((line, i) => [line, b[i]]).filter(([x, y]) => x !== y);
    assert.equal(diff.length, 1);
    assert.match(diff[0][0], /function legacyV1WritesOpen\(\) \{ return true; \} \/\/ @mig03-switch/);
    assert.match(diff[0][1], /function legacyV1WritesOpen\(\) \{ return false; \} \/\/ @mig03-switch/);
    // 원본 파일은 여전히 true다(사본만 바뀜).
    assert.match(h.readRulesText(), /function legacyV1WritesOpen\(\) \{ return true; \}/);
  });
});

for (const soapV2 of [false, true]) {
  describe(`switch closed, soapV2=${soapV2} (AC-DF-022.3)`, () => {
    test(`R-21 v1 frozen-app create is denied when the switch is closed and soapV2=${soapV2}`, async () => {
      await seedS0(closedEnv, {soapV2});
      await assertFails(setDoc(doc(h.trainerDb(closedEnv), 'soap_notes/L2'), h.v1SoapDoc()));
    });

    test(`R-21 v1 update of an existing v1 note is denied when the switch is closed and soapV2=${soapV2}`, async () => {
      await seedS0(closedEnv, {soapV2});
      const ref = doc(h.trainerDb(closedEnv), 'soap_notes/L1');
      await assertFails(setDoc(ref, h.v1SoapDoc({subjective: '수정한 합성 메모'})));
      await assertFails(updateDoc(ref, {subjective: '수정한 합성 메모', updatedAt: Date.now()}));
    });

    test(`R-21 v1 delete is denied when the switch is closed and soapV2=${soapV2}`, async () => {
      await seedS0(closedEnv, {soapV2});
      await assertFails(deleteDoc(doc(h.trainerDb(closedEnv), 'soap_notes/L1')));
    });
  });
}

describe('switch copy keeps the v2 path (AC-DF-022.3 control)', () => {
  test('R-21 control: v2 draft create still passes on the switched copy with soapV2=true', async () => {
    await seedS0(closedEnv, {soapV2: true});
    await assertSucceeds(setDoc(doc(h.trainerDb(closedEnv), 'soap_notes/fx-new-210'), h.v2SoapDoc()));
  });
});

describe('original rules keep the frozen app working (AC-DF-022.3)', () => {
  test('R-21 original rules (switch true) allow the frozen-app v1 create', async () => {
    await seedS0(openEnv, {soapV2: true});
    await assertSucceeds(setDoc(doc(h.trainerDb(openEnv), 'soap_notes/L2'), h.v1SoapDoc()));
  });

  test('R-21 original rules allow the frozen-app v1 update of an existing v1 note', async () => {
    await seedS0(openEnv, {soapV2: false});
    await assertSucceeds(setDoc(doc(h.trainerDb(openEnv), 'soap_notes/L1'),
      h.v1SoapDoc({subjective: '수정한 합성 메모'})));
  });
});
