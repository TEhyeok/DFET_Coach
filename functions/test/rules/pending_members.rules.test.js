// DF-035 대기 회원 규칙: R-18, R-19, R-30, R-31과 AC-DF-035.3 birthYear 경계(TC-DF035-97). V1-05 §7.4.
// DF-113 AC-DF-113.6·DF-110 AC-DF-110.5: 트레이너 앱의 등록 취소(Outbox update `status: 'cancelled'` + 서버 시각 `updatedAt`).
// request.time.year()는 UTC 기준이라 기대 연도도 UTC로 계산한다(ASM-P0-26). 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, serverTimestamp, setDoc, updateDoc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, pendA} = h.IDS;
// request.time.year()와 같은 UTC 연도. 확인 도중 1월 1일 00:00 UTC를 넘어 실패하면 새 연도로 한 번 더 확인한다.
const utcYear = () => new Date().getUTCFullYear();
async function atStableYear(check) {
  const year = utcYear();
  try {
    await check(year);
  } catch (err) {
    if (utcYear() === year) throw err;
    await check(utcYear());
  }
}
let env;
let seq = 0;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-pending-members'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// 대기 회원 pendA(생성자 A). status와 동의 ②를 바꿔 가며 쓴다.
async function seedPending({status = 'pending', consent = {healthData: true}} = {}) {
  await h.seed(env, {
    ...h.seedTrainer(trainerA, []),
    [`pendingMembers/${pendA}`]: h.pendingMemberDoc({status}),
    ...(consent ? h.seedConsent(pendA, consent) : {}),
    ...h.seedFlags({soapV2: true}),
  });
}

// memberUid·memberId 대신 pendingMemberId를 키로 쓰는 v2 SOAP draft
function pendingSoapDoc() {
  return {...h.withoutKeys(h.v2SoapDoc(), 'memberUid', 'memberId'), pendingMemberId: pendA};
}

function createSoap() {
  seq += 1;
  return setDoc(doc(h.trainerDb(env), `soap_notes/fx-pending-note-${seq}`), pendingSoapDoc());
}

function updateHeight() {
  return updateDoc(doc(h.trainerDb(env), `pendingMembers/${pendA}`), {
    heightCm: 170.5, heightMeasuredAt: h.hoursAgo(1), updatedAt: serverTimestamp(),
  });
}

// 클라이언트 자동 ID 형식(20자 [A-Za-z0-9], V1-04 §9.1)
function newPendingId() {
  seq += 1;
  return `FxPendingBirth${String(seq).padStart(6, '0')}`;
}

function createPending(overrides) {
  return setDoc(doc(h.trainerDb(env), `pendingMembers/${newPendingId()}`), h.pendingMemberCreateDoc(overrides));
}

describe('soap_notes keyed by a pending member (R-18, R-19)', () => {
  test('R-18 creator trainer, pending status and consent ② on the pending key: soap create is allowed', async () => {
    await seedPending();
    await assertSucceeds(createSoap());
  });

  test('R-19 the same create when the pending member is cancelled is denied', async () => {
    await seedPending({status: 'cancelled'});
    await assertFails(createSoap());
  });

  test('R-19 the same create by another trainer is denied', async () => {
    await seedPending();
    await h.seed(env, h.seedTrainer(h.IDS.trainerB, []));
    await assertFails(setDoc(doc(h.trainerDb(env, h.IDS.trainerB), 'soap_notes/fx-pending-note-b'), {
      ...pendingSoapDoc(), trainerId: h.IDS.trainerB, authorUid: h.IDS.trainerB,
    }));
  });
});

describe('pendingMembers heightCm needs consent ② (R-30)', () => {
  test('R-30 control: heightCm update with consent ② is allowed', async () => {
    await seedPending();
    await assertSucceeds(updateHeight());
  });

  test('R-30 heightCm update without a consent state document is denied', async () => {
    await seedPending({consent: null});
    await assertFails(updateHeight());
  });

  test('R-30 heightCm update with healthData not granted is denied', async () => {
    await seedPending({consent: {healthData: false}});
    await assertFails(updateHeight());
  });
});

describe('pendingMembers birthYear (R-31, AC-DF-035.3)', () => {
  beforeEach(async () => {
    await h.seed(env, h.seedTrainer(trainerA, []));
  });

  test('R-31 birthYear = Y-13 is denied', async () => {
    await atStableYear(async (Y) => {
      await assertFails(createPending({birthYear: Y - 13}));
    });
  });

  test('R-31 TC-DF035-97 birthYear Y-14 is allowed, Y-13 and 1899 are denied', async () => {
    await atStableYear(async (Y) => {
      await assertSucceeds(createPending({birthYear: Y - 14}));
      await assertFails(createPending({birthYear: Y - 13}));
      await assertFails(createPending({birthYear: 1899}));
    });
  });

  test('R-31 control: birthYear 1900 is allowed', async () => {
    await assertSucceeds(createPending({birthYear: 1900}));
  });
});

// 트레이너 앱이 보내는 모양 그대로: Outbox 페이로드 {status: 'cancelled'}에 FirestoreRemoteWriter.update가 서버 시각
// updatedAt을 더한다. cancelledAt은 서버 필드라 앱이 쓰지 않는다(V1-05 §4.3).
function cancelAs(uid = trainerA, extra = {}) {
  return updateDoc(doc(h.trainerDb(env, uid), `pendingMembers/${pendA}`), {
    status: 'cancelled', updatedAt: serverTimestamp(), ...extra,
  });
}

describe('pendingMembers cancel from the trainer app (AC-DF-113.6, AC-DF-110.5, F-LINK-01.5)', () => {
  test('the creator cancels a pending member with the Outbox payload', async () => {
    await seedPending({consent: null});
    await assertSucceeds(cancelAs());
  });

  test('another trainer cannot cancel it', async () => {
    await seedPending({consent: null});
    await h.seed(env, h.seedTrainer(h.IDS.trainerB, []));
    await assertFails(cancelAs(h.IDS.trainerB));
  });

  test('a client cancelledAt (server field) or a client updatedAt is denied', async () => {
    await seedPending({consent: null});
    await assertFails(cancelAs(trainerA, {cancelledAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(h.trainerDb(env), `pendingMembers/${pendA}`), {
      status: 'cancelled', updatedAt: h.hoursAgo(1),
    }));
  });

  test('a cancelled member cannot be cancelled again or brought back; its consent state is no longer readable', async () => {
    await seedPending({status: 'cancelled', consent: {required: true, healthData: true}});
    await assertFails(cancelAs());
    await assertFails(updateDoc(doc(h.trainerDb(env), `pendingMembers/${pendA}`), {
      status: 'pending', updatedAt: serverTimestamp(),
    }));
    // isPendingOwner needs status 'pending': the TR-02 chip listener of a cancelled member is refused.
    await assertFails(getDoc(doc(h.trainerDb(env), `memberConsentStates/${pendA}`)));
  });

  test('control: the creator reads the consent state while the member is pending', async () => {
    await seedPending({consent: {required: true, healthData: true}});
    await assertSucceeds(getDoc(doc(h.trainerDb(env), `memberConsentStates/${pendA}`)));
  });
});
