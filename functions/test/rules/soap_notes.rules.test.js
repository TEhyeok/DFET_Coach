// DF-022 soap_notes 규칙 매트릭스: R-01~R-04, R-08, R-09, R-13, R-24 (V1-05 §9.2, AC-DF-022.1).
// TC-DF022-R01 … TC-DF022-R24 중 soap_notes 몫. 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {
  collection, doc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1, member2} = h.IDS;
let env;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-soap-notes'});
});

after(async () => {
  await env.cleanup();
});

// R-01 조건: trainers/trainerA.memberIds=[member1], member1 healthData 동의, soapV2=true
async function seedR01({memberIdsA = [member1]} = {}) {
  await h.seed(env, {
    ...h.seedTrainer(trainerA, memberIdsA),
    ...h.seedTrainer(trainerB, [member2]),
    ...h.seedConsent(member1, {healthData: true}),
    ...h.seedConsent(member2, {healthData: true}),
    ...h.seedFlags({soapV2: true}),
    'soap_notes/N1': h.storedV2SoapDoc(),
    'soap_notes/N2': h.storedV2SoapDoc({status: 'finalized', finalizedAt: h.hoursAgo(1)}),
    'soap_notes/N2/addenda/A1': {
      authorUid: trainerA, createdAt: h.hoursAgo(1), reason: '합성 정정 사유', text: '합성 정정 문장',
    },
  });
}

beforeEach(async () => {
  await env.clearFirestore();
});

describe('soap_notes create (AC-DF-022.1)', () => {
  test('R-01 assigned trainer with healthData consent and soapV2=true creates a v2 draft', async () => {
    await seedR01();
    await assertSucceeds(setDoc(doc(h.trainerDb(env), 'soap_notes/fx-new-001'), h.v2SoapDoc()));
  });

  test('R-02 trainer whose memberIds is empty cannot create for member1 even with trainerId == uid', async () => {
    await seedR01({memberIdsA: []});
    await assertFails(setDoc(doc(h.trainerDb(env), 'soap_notes/fx-new-002'), h.v2SoapDoc()));
  });

  test('R-02 trainer cannot create for a member outside memberIds (member2 belongs to trainerB)', async () => {
    await seedR01();
    await assertFails(setDoc(doc(h.trainerDb(env), 'soap_notes/fx-new-003'), h.v2SoapDoc({
      memberUid: member2, memberId: member2,
    })));
  });
});

describe('soap_notes draft update keeps the keys fixed (AC-DF-022.1)', () => {
  test('R-03 changing memberUid to member2 on the R-01 document is denied', async () => {
    await seedR01();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N1'), {
      memberUid: member2, updatedAt: serverTimestamp(),
    }));
  });

  test('R-03 changing trainerId to trainerB on the R-01 document is denied', async () => {
    await seedR01();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N1'), {
      trainerId: trainerB, updatedAt: serverTimestamp(),
    }));
  });

  test('R-03 control: an ordinary draft edit by the same trainer is allowed', async () => {
    await seedR01();
    await assertSucceeds(updateDoc(doc(h.trainerDb(env), 'soap_notes/N1'), {
      quickNote: '수정한 합성 메모', updatedAt: serverTimestamp(),
    }));
  });
});

describe('soap_notes has no diagnosis field (AC-DF-022.1, AC-PRIV-06.1)', () => {
  test('R-04 create including diagnosis is denied', async () => {
    await seedR01();
    await assertFails(setDoc(doc(h.trainerDb(env), 'soap_notes/fx-new-004'), h.v2SoapDoc({
      diagnosis: 'x',
    })));
  });

  test('R-04 update adding diagnosis is denied', async () => {
    await seedR01();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N1'), {
      diagnosis: 'x', updatedAt: serverTimestamp(),
    }));
  });
});

describe('soap_notes finalized is immutable (AC-DF-022.1, AC-SOAP-04.1~04.3)', () => {
  test('R-08 update of exerciseAssessment on a finalized note is denied', async () => {
    await seedR01();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N2'), {
      exerciseAssessment: {summary: '합성 요약'}, updatedAt: serverTimestamp(),
    }));
  });

  test('R-08 moving a finalized note back to draft or editing quickNote is denied', async () => {
    await seedR01();
    const ref = doc(h.trainerDb(env), 'soap_notes/N2');
    await assertFails(updateDoc(ref, {status: 'draft', updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {quickNote: '합성 수정', updatedAt: serverTimestamp()}));
  });

  test('R-09 addendum create with a reason on a finalized note is allowed', async () => {
    await seedR01();
    await assertSucceeds(setDoc(doc(h.trainerDb(env), 'soap_notes/N2/addenda/A2'), {
      authorUid: trainerA, createdAt: serverTimestamp(), reason: '합성 정정 사유', text: '합성 정정 문장',
      changedFields: ['plan.nextSession'], previousValues: {'plan.nextSession': '이전 합성 계획'},
    }));
  });

  test('R-09 addendum update is denied', async () => {
    await seedR01();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N2/addenda/A1'), {
      text: '바꾼 합성 문장',
    }));
  });
});

describe('soap_notes list must be proven by trainerId (AC-DF-022.1)', () => {
  test('R-13 list filtered only by memberUid == member1 is denied', async () => {
    await seedR01();
    await assertFails(getDocs(query(
      collection(h.trainerDb(env), 'soap_notes'), where('memberUid', '==', member1),
    )));
  });

  test('R-13 control: list filtered by trainerId == uid and memberUid is allowed', async () => {
    await seedR01();
    await assertSucceeds(getDocs(query(
      collection(h.trainerDb(env), 'soap_notes'),
      where('trainerId', '==', trainerA), where('memberUid', '==', member1),
    )));
  });
});

describe('soap_notes native_ document IDs (AC-DF-022.1)', () => {
  test('R-24 create with document ID native_x_2026-09-24 under R-01 conditions is denied', async () => {
    await seedR01();
    await assertFails(setDoc(doc(h.trainerDb(env), 'soap_notes/native_x_2026-09-24'), h.v2SoapDoc()));
  });
});
