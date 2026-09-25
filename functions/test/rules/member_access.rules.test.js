// DF-022 회원·관리자 접근 규칙: R-10~R-12, R-23 (V1-05 §9.2, AC-DF-022.1, AC-LINK-05.1·05.2, F-PRIV-05.2).
// 회원이 읽는 공유 문서는 memberSummaries 하나뿐이고(ADR-006), 원 기록은 회원·관리자 클라이언트가 읽지 못한다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {collection, doc, getDoc, getDocs, orderBy, query, where} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1, member2} = h.IDS;
let env;

// memberSummaries 규칙은 DF-021(요약 규칙은 P2로 연기, DEC-22)이 추가한다. 규칙이 main에 없는 동안
// R-11은 기본 거부로 실패하므로 todo로 보고하고(실행은 한다), 규칙이 들어오면 자동으로 일반 테스트가 된다.
const SUMMARY_RULES_PRESENT = /match \/memberSummaries\/\{/.test(h.readRulesText());
const R11_TODO = SUMMARY_RULES_PRESENT
  ? false
  : 'memberSummaries rule is not in firestore.rules yet (DF-021 / P2 DF-309); reported as DF-022 failure list';

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-member-access'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  const docs = {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedTrainer(trainerB, [member2]),
    ...h.seedConsent(member1, {healthData: true, bodyImaging: true}),
    ...h.seedFlags(),
    'soap_notes/N1': h.storedV2SoapDoc(),
    'soap_notes/L1': h.v1SoapDoc({isSharedWithMember: true}),
    'memberSummaries/s1': h.memberSummaryDoc({memberUid: member1}),
  };
  for (const col of h.RAW_RECORD_COLLECTIONS.filter((c) => c !== 'soap_notes')) {
    docs[`${col}/R1`] = h.rawRecordDoc(col);
  }
  await h.seed(env, docs);
});

describe('member cannot read raw records (AC-DF-022.1, AC-LINK-05.1)', () => {
  test('R-10 member1 get of soap, posture, bodyComposition, circumference and bodyScans documents is denied', async () => {
    const db = h.memberDb(env, member1);
    await assertFails(getDoc(doc(db, 'soap_notes/N1')));
    await assertFails(getDoc(doc(db, 'soap_notes/L1'))); // v1 isSharedWithMember=true도 거부
    for (const col of h.RAW_RECORD_COLLECTIONS.filter((c) => c !== 'soap_notes')) {
      await assertFails(getDoc(doc(db, `${col}/R1`)));
    }
  });

  test('R-10 member1 list with where memberUid == member1 on raw records is denied', async () => {
    const db = h.memberDb(env, member1);
    for (const col of h.RAW_RECORD_COLLECTIONS) {
      await assertFails(getDocs(query(collection(db, col), where('memberUid', '==', member1))));
    }
  });
});

describe('member reads only their own memberSummaries (AC-DF-022.1, AC-LINK-05.2)', () => {
  test('R-11 member1 lists memberSummaries where memberUid == member1', {todo: R11_TODO}, async () => {
    const db = h.memberDb(env, member1);
    await assertSucceeds(getDocs(query(
      collection(db, 'memberSummaries'), where('memberUid', '==', member1), orderBy('sharedAt', 'desc'),
    )));
  });

  test('R-12 member2 list of memberSummaries where memberUid == member1 is denied', async () => {
    const db = h.memberDb(env, member2);
    await assertFails(getDocs(query(collection(db, 'memberSummaries'), where('memberUid', '==', member1))));
  });

  test('R-12 member2 get of member1 summary is denied', async () => {
    await assertFails(getDoc(doc(h.memberDb(env, member2), 'memberSummaries/s1')));
  });
});

describe('admin claim without trainer claim cannot read raw records (AC-DF-022.1, F-PRIV-05.2)', () => {
  test('R-23 admin:true token get of soap, posture, bodyComposition, circumference and bodyScans is denied', async () => {
    const db = h.adminDb(env);
    await assertFails(getDoc(doc(db, 'soap_notes/N1')));
    await assertFails(getDoc(doc(db, 'soap_notes/L1')));
    for (const col of h.RAW_RECORD_COLLECTIONS.filter((c) => c !== 'soap_notes')) {
      await assertFails(getDoc(doc(db, `${col}/R1`)));
    }
  });

  test('R-23 admin listed in the admins collection (approved) still cannot get a soap note', async () => {
    await h.seed(env, {[`admins/${h.IDS.adminX}`]: {role: 'admin', approvalStatus: 'approved'}});
    await assertFails(getDoc(doc(h.adminDb(env), 'soap_notes/N1')));
  });

  test('R-23 control: the assigned trainer can get the same soap note', async () => {
    await assertSucceeds(getDoc(doc(h.trainerDb(env, trainerA), 'soap_notes/N1')));
  });
});
