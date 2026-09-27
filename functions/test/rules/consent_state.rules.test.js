// DF-109 TC-109-09 (AC-DF-109.1, R-20) for the pending-member path: the trainer who owns a pending member can read
// its consent state and records but cannot write either, not even a first state for its own pending member.
// The state documents here are built with the server's derive() (src/consent/core/deriveConsentState.js), so the
// test also shows that the shape recordConsent writes is what hasConsent() reads (R-01 soap create for the pending
// member). All identifiers and values are synthetic.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {deleteDoc, doc, getDoc, setDoc, updateDoc} = require('firebase/firestore');
const h = require('./_harness');
const {derive} = require('../../src/consent/core/deriveConsentState');

const {trainerA, trainerB, pendA} = h.IDS;
const PEND_REQUIRED_ONLY = 'pendRequiredOnly';
const PEND_NO_STATE = 'pendNoState';
let env;
let seq = 0;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-consent-state'});
});

after(async () => {
  await env.cleanup();
});

function consentRecord(pendingMemberId, consentType, recordedAt) {
  return {
    subjectUid: null, pendingMemberId, consentType, action: 'grant', documentVersion: `${consentType}--test-1`,
    channel: 'trainerDeviceInPerson', recordedAt, recordedBy: trainerA, capturedAt: null, signaturePath: null,
    reconfirmedAt: null, reconfirmOf: null, clientCaptureId: `cap_${pendingMemberId}`, schemaVersion: 1,
  };
}

// memberConsentStates document as recordConsent writes it: derive() entries + updatedAt + schemaVersion.
function derivedState(pendingMemberId, types) {
  const recordedAt = h.hoursAgo(1);
  const records = types.map((type) => ({recordId: `fx-${pendingMemberId}-${type}`, ...consentRecord(pendingMemberId, type, recordedAt)}));
  return {...derive(null, records), updatedAt: recordedAt, schemaVersion: 1};
}

beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, []),
    ...h.seedTrainer(trainerB, []),
    ...h.seedFlags({soapV2: true}),
    [`pendingMembers/${pendA}`]: h.pendingMemberDoc(),
    [`pendingMembers/${PEND_REQUIRED_ONLY}`]: h.pendingMemberDoc(),
    [`pendingMembers/${PEND_NO_STATE}`]: h.pendingMemberDoc(),
    [`memberConsentStates/${pendA}`]: derivedState(pendA, ['required', 'healthData', 'bodyImaging']),
    [`memberConsentStates/${PEND_REQUIRED_ONLY}`]: derivedState(PEND_REQUIRED_ONLY, ['required']),
    'consentRecords/fx-pendA-healthData': consentRecord(pendA, 'healthData', h.hoursAgo(1)),
  });
});

function pendingSoapDoc(pendingMemberId) {
  return {...h.withoutKeys(h.v2SoapDoc(), 'memberUid', 'memberId'), pendingMemberId};
}

function createSoap(db, pendingMemberId) {
  seq += 1;
  return setDoc(doc(db, `soap_notes/fx-consent-note-${seq}`), pendingSoapDoc(pendingMemberId));
}

describe('pending owner reads but never writes consent documents (AC-DF-109.1, R-20)', () => {
  test('R-20 owner A reads memberConsentStates and consentRecords of its pending member; trainer B cannot', async () => {
    await assertSucceeds(getDoc(doc(h.trainerDb(env, trainerA), `memberConsentStates/${pendA}`)));
    await assertSucceeds(getDoc(doc(h.trainerDb(env, trainerA), 'consentRecords/fx-pendA-healthData')));
    await assertFails(getDoc(doc(h.trainerDb(env, trainerB), `memberConsentStates/${pendA}`)));
    await assertFails(getDoc(doc(h.trainerDb(env, trainerB), 'consentRecords/fx-pendA-healthData')));
  });

  test('R-20 owner A cannot create a first consent state for its own pending member', async () => {
    const db = h.trainerDb(env, trainerA);
    await assertFails(setDoc(doc(db, `memberConsentStates/${PEND_NO_STATE}`),
      derivedState(PEND_NO_STATE, ['required', 'healthData'])));
  });

  test('R-20 owner A cannot update, overwrite or delete the derived state', async () => {
    const db = h.trainerDb(env, trainerA);
    await assertFails(updateDoc(doc(db, `memberConsentStates/${PEND_REQUIRED_ONLY}`),
      {healthData: {granted: true, documentVersion: 'healthData--test-1', recordId: 'fx-forged', updatedAt: h.hoursAgo(0)}}));
    await assertFails(setDoc(doc(db, `memberConsentStates/${PEND_REQUIRED_ONLY}`),
      derivedState(PEND_REQUIRED_ONLY, ['required', 'healthData'])));
    await assertFails(deleteDoc(doc(db, `memberConsentStates/${pendA}`)));
  });

  test('R-20 owner A cannot create, change or delete consent records for its pending member', async () => {
    const db = h.trainerDb(env, trainerA);
    await assertFails(setDoc(doc(db, 'consentRecords/fx-client-record'),
      consentRecord(PEND_NO_STATE, 'healthData', h.hoursAgo(0))));
    await assertFails(updateDoc(doc(db, 'consentRecords/fx-pendA-healthData'), {action: 'withdraw'}));
    await assertFails(deleteDoc(doc(db, 'consentRecords/fx-pendA-healthData')));
  });
});

describe('the derived state is what hasConsent() reads (R-01 for a pending member)', () => {
  test('R-01 derived ①②③ grants: owner A may create a v2 SOAP draft for the pending member', async () => {
    await assertSucceeds(createSoap(h.trainerDb(env, trainerA), pendA));
  });

  test('R-01 derived ① only (no ②): the SOAP draft is denied; no state document: denied', async () => {
    await assertFails(createSoap(h.trainerDb(env, trainerA), PEND_REQUIRED_ONLY));
    await assertFails(createSoap(h.trainerDb(env, trainerA), PEND_NO_STATE));
  });
});
