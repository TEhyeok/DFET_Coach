// DF-035 서버 전용 컬렉션: R-20(AC-PRIV-02.1). 회원·트레이너·관리자 토큰 모두 클라이언트 쓰기가 거부된다.
// 각 역할이 읽을 수 있는 문서에도 쓸 수 없음을 보인다. 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {deleteDoc, doc, getDoc, setDoc, updateDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, member1, adminX} = h.IDS;
const COLLECTIONS = [
  'consentRecords', 'memberConsentStates', 'inviteCodes', 'memberSummaries', 'rightsRequests', 'opsMetrics',
];
let env;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-server-only'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedConsent(member1, {healthData: true}),
    'consentRecords/fx-consent-001': {
      subjectUid: member1, pendingMemberId: null, consentType: 'healthData', action: 'grant',
      documentVersion: 'fx-v1', channel: 'memberApp', recordedAt: h.hoursAgo(3), recordedBy: member1,
      schemaVersion: 1,
    },
    'inviteCodes/fx-code-hash': {pendingMemberId: 'fx-pending-001', status: 'active'},
    'memberSummaries/fx-summary-001': h.memberSummaryDoc(),
    'rightsRequests/fx-rights-001': {memberUid: member1, type: 'access', channel: 'memberApp', status: 'received'},
    'opsMetrics/2026-W40': {weekSoapFinalized: 3},
  });
});

// 역할별로 가장 그럴듯한 페이로드: 자기 uid·담당 회원·관리자 claim을 모두 갖췄다.
function clients() {
  return [
    ['member', h.memberDb(env), {memberUid: member1, subjectUid: member1}],
    ['trainer', h.trainerDb(env), {memberUid: member1, subjectUid: member1, trainerId: trainerA}],
    ['admin', h.adminDb(env), {memberUid: member1, subjectUid: member1, recordedBy: adminX}],
  ];
}

// 각 컬렉션에서 이미 서버가 쓴 문서
const EXISTING = {
  consentRecords: 'consentRecords/fx-consent-001',
  memberConsentStates: `memberConsentStates/${member1}`,
  inviteCodes: 'inviteCodes/fx-code-hash',
  memberSummaries: 'memberSummaries/fx-summary-001',
  rightsRequests: 'rightsRequests/fx-rights-001',
  opsMetrics: 'opsMetrics/2026-W40',
};

describe('server-only collections reject every client write (R-20)', () => {
  for (const name of COLLECTIONS) {
    test(`R-20 ${name}: member, trainer and admin tokens cannot create`, async () => {
      for (const [who, db, payload] of clients()) {
        await assertFails(setDoc(doc(db, `${name}/fx-client-${who}`), {...payload, schemaVersion: 1}));
      }
    });

    test(`R-20 ${name}: member, trainer and admin tokens cannot update or delete a server-written document`, async () => {
      for (const [, db] of clients()) {
        await assertFails(updateDoc(doc(db, EXISTING[name]), {status: 'fx-changed'}));
        await assertFails(deleteDoc(doc(db, EXISTING[name])));
      }
    });
  }

  test('R-20 member cannot overwrite its own consent state even though it can read it', async () => {
    const member = h.memberDb(env);
    await assertSucceeds(getDoc(doc(member, `memberConsentStates/${member1}`)));
    await assertFails(setDoc(doc(member, `memberConsentStates/${member1}`), {
      healthData: {granted: false, updatedAt: h.hoursAgo(1)},
    }));
  });

  test('R-20 assigned trainer cannot write a summary for its own member even though it can read it', async () => {
    const trainer = h.trainerDb(env);
    await assertSucceeds(getDoc(doc(trainer, 'memberSummaries/fx-summary-001')));
    await assertFails(setDoc(doc(trainer, 'memberSummaries/fx-summary-001'), h.memberSummaryDoc({title: '바꾼 요약'})));
  });
});
