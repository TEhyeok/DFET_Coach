// DF-035 동의 기록 읽기: R-28(AC-PRIV-01.1). 담당 트레이너만 회원의 동의 기록을 조회한다(V1-05 §7.9).
// 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {collection, getDocs, query, where} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1, member2} = h.IDS;
let env;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-consent-read'});
});

after(async () => {
  await env.cleanup();
});

function consentRecord(subjectUid, consentType) {
  return {
    subjectUid, pendingMemberId: null, consentType, action: 'grant', documentVersion: 'fx-v1',
    channel: 'memberApp', recordedAt: h.hoursAgo(3), recordedBy: subjectUid, schemaVersion: 1,
  };
}

beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedTrainer(trainerB, [member2]),
    'consentRecords/fx-consent-001': consentRecord(member1, 'healthData'),
    'consentRecords/fx-consent-002': consentRecord(member1, 'bodyImaging'),
  });
});

function listFor(db) {
  return getDocs(query(collection(db, 'consentRecords'), where('subjectUid', '==', member1)));
}

describe('consentRecords list by subjectUid (R-28)', () => {
  test('R-28 assigned trainer A lists member1 consent records', async () => {
    await assertSucceeds(listFor(h.trainerDb(env, trainerA)));
  });

  test('R-28 unassigned trainer B cannot list member1 consent records', async () => {
    await assertFails(listFor(h.trainerDb(env, trainerB)));
  });
});
