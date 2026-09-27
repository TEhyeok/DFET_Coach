'use strict';

// DF-109 recordConsent against the emulators (MVP scope, DEC-22): TC-109-05 (records and state, without signature),
// TC-109-06 pending-member ownership, TC-109-07 document version checks, TC-109-08 idempotent replay, plus auth,
// ① first and derivation of each type ①②③. Needs the Firestore emulator; the last block also calls the deployed
// function through the Functions and Auth emulators:
//   firebase emulators:exec --only auth,functions,firestore,storage --project demo-dfet "npm --prefix functions run test:e2e"
// The published consent documents come from the test document publish script's builder (never run with --apply
// here: publishConsentDocuments() is called on the emulator database). Every ID and value is synthetic.

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {after, before, describe, test} = require('node:test');
const {deleteApp, initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {recordConsentCore} = require('../../src/consent/recordConsent');
const {
  PublishError,
  buildTestConsentDocuments,
  loadDeck,
  publishConsentDocuments,
} = require('../../scripts/publish-test-consent-documents');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'demo-dfet';
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const TRAINER_A = 'synthConsentTrainerA';
const TRAINER_B = 'synthConsentTrainerB';
const PASSWORD = 'emulator-only-password';
const DOC = {required: 'required--test-1', healthData: 'healthData--test-1', bodyImaging: 'bodyImaging--test-1'};
const RECORD_KEYS = [
  'capturedAt', 'channel', 'clientCaptureId', 'consentType', 'action', 'documentVersion', 'pendingMemberId',
  'reconfirmOf', 'reconfirmedAt', 'recordedAt', 'recordedBy', 'schemaVersion', 'signaturePath', 'subjectUid',
].sort();
let app;
let db;

const trainer = (uid) => ({uid, token: {trainer: true}});
const alnum = (n) => crypto.randomBytes(n).toString('base64').replace(/[^A-Za-z0-9]/g, '').padEnd(n, 'x').slice(0, n);
const newPendingId = () => `SYNTHp${alnum(14)}`;
const newCaptureId = () => crypto.randomUUID();

function selection(consentType, documentVersion = DOC[consentType]) {
  return {consentType, action: 'grant', documentVersion};
}

function payload(pendingMemberId, selections, overrides = {}) {
  return {
    clientCaptureId: newCaptureId(),
    memberKey: {pendingMemberId},
    channel: 'trainerDeviceInPerson',
    selections,
    ...overrides,
  };
}

function call(data, auth = trainer(TRAINER_A)) {
  return recordConsentCore({db, now: () => Timestamp.now(), auth, data});
}

async function seedPending({trainerId = TRAINER_A, status = 'pending'} = {}) {
  const id = newPendingId();
  const at = Timestamp.now();
  await db.doc(`pendingMembers/${id}`).set({
    trainerId, displayName: '가상회원 동의', sex: 'unspecified', birthYear: 1994, ageConfirmed14: true,
    status, schemaVersion: 1, createdAt: at, updatedAt: at,
  });
  return id;
}

async function recordsOf(captureId) {
  const snap = await db.collection('consentRecords').where('clientCaptureId', '==', captureId).get();
  return snap.docs;
}

async function assertNothingWritten(data) {
  assert.equal((await recordsOf(data.clientCaptureId)).length, 0, 'no consentRecords');
  const state = await db.doc(`memberConsentStates/${data.memberKey.pendingMemberId}`).get();
  assert.equal(state.exists, false, 'no memberConsentStates');
}

async function rejectsWith(promise, code, messageKey, fields) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, code, `${error.code}: ${error.message}`);
    assert.equal(error.message, messageKey);
    assert.equal(error.details.messageKey, messageKey);
    if (fields) assert.deepEqual(error.details.fields, fields);
    return true;
  });
}

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore Emulator is required');
  app = initializeApp({projectId}, 'record-consent-e2e');
  db = getFirestore(app);
  await publishConsentDocuments(db, buildTestConsentDocuments(loadDeck()));
  await db.doc('consentDocumentVersions/healthData--draft-9').set({
    consentType: 'healthData', version: 'draft-9', status: 'draft', publishedAt: null, schemaVersion: 1,
  });
  await db.doc('consentDocumentVersions/bodyImaging--retired-0').set({
    consentType: 'bodyImaging', version: 'retired-0', status: 'retired', publishedAt: Timestamp.now(), schemaVersion: 1,
  });
});

after(async () => {
  if (app) await deleteApp(app);
});

describe('recordConsent core on the Firestore emulator', () => {
  test('TC-109-05 pending owner A grants ①②③: three records, derived state, signaturePath null', async () => {
    const pendingId = await seedPending();
    const capturedAt = new Date(Date.now() - 60 * 1000).toISOString();
    const data = payload(pendingId, [selection('bodyImaging'), selection('required'), selection('healthData')],
      {capturedAt, reconfirmOf: null});
    const result = await call(data);

    assert.equal(result.ok, true);
    assert.equal(result.replayed, false);
    assert.equal(result.signaturePath, null);
    assert.equal(result.recordIds.length, 3);
    assert.deepEqual(Object.keys(result.state), ['required', 'healthData', 'bodyImaging']);
    ['required', 'healthData', 'bodyImaging'].forEach((type, i) => {
      const entry = result.state[type];
      assert.deepEqual(Object.keys(entry).sort(), ['documentVersion', 'granted', 'recordId', 'updatedAt']);
      assert.equal(entry.granted, true);
      assert.equal(entry.documentVersion, DOC[type]);
      assert.equal(entry.recordId, result.recordIds[i], 'recordIds follow the consent type order');
      assert.match(entry.updatedAt, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });

    const docs = await recordsOf(data.clientCaptureId);
    assert.deepEqual(docs.map((d) => d.id).sort(), [...result.recordIds].sort());
    const recordedAt = docs[0].get('recordedAt');
    for (const snap of docs) {
      const record = snap.data();
      assert.deepEqual(Object.keys(record).sort(), RECORD_KEYS);
      assert.equal(record.subjectUid, null);
      assert.equal(record.pendingMemberId, pendingId);
      assert.equal(record.action, 'grant');
      assert.equal(record.documentVersion, DOC[record.consentType]);
      assert.equal(record.channel, 'trainerDeviceInPerson');
      assert.equal(record.recordedBy, TRAINER_A);
      assert.equal(record.signaturePath, null);
      assert.equal(record.reconfirmedAt, null);
      assert.equal(record.reconfirmOf, null);
      assert.equal(record.schemaVersion, 1);
      assert.equal(record.capturedAt.toDate().toISOString(), capturedAt);
      assert.ok(record.recordedAt.isEqual(recordedAt), 'one recordedAt for the whole call');
    }

    const state = (await db.doc(`memberConsentStates/${pendingId}`).get()).data();
    assert.deepEqual(Object.keys(state).sort(), ['bodyImaging', 'healthData', 'required', 'schemaVersion', 'updatedAt']);
    assert.equal(state.schemaVersion, 1);
    assert.ok(state.updatedAt.isEqual(recordedAt));
    for (const type of ['required', 'healthData', 'bodyImaging']) {
      assert.equal(state[type].granted, true);
      assert.equal(state[type].documentVersion, DOC[type]);
      assert.equal(state[type].recordId, result.state[type].recordId);
      assert.ok(state[type].updatedAt.isEqual(recordedAt));
    }
  });

  test('derivation of each type: ① then ② then ③ in separate captures, earlier entries kept', async () => {
    const pendingId = await seedPending();
    const stateOf = async () => (await db.doc(`memberConsentStates/${pendingId}`).get()).data();

    const first = await call(payload(pendingId, [selection('required')]));
    assert.deepEqual(Object.keys(first.state), ['required']);
    assert.deepEqual(Object.keys(await stateOf()).sort(), ['required', 'schemaVersion', 'updatedAt']);

    const second = await call(payload(pendingId, [selection('healthData')]));
    assert.deepEqual(Object.keys(second.state), ['required', 'healthData']);
    assert.equal(second.state.required.recordId, first.recordIds[0], '① entry unchanged');
    assert.equal(second.state.healthData.recordId, second.recordIds[0]);

    const third = await call(payload(pendingId, [selection('bodyImaging')]));
    assert.deepEqual(Object.keys(third.state), ['required', 'healthData', 'bodyImaging']);
    assert.equal(third.state.healthData.recordId, second.recordIds[0], '② entry unchanged');
    assert.equal(third.state.bodyImaging.recordId, third.recordIds[0]);
    const stored = await stateOf();
    for (const type of ['required', 'healthData', 'bodyImaging']) {
      assert.equal(stored[type].recordId, third.state[type].recordId, type);
      assert.equal(stored[type].granted, true, type);
    }
  });

  test('TC-109-08 AC-DF-109.6 same clientCaptureId twice: one set of records, same recordIds, replayed', async () => {
    const pendingId = await seedPending();
    const data = payload(pendingId, [selection('required'), selection('healthData'), selection('bodyImaging')]);
    const first = await call(data);
    const second = await call(data);
    const reordered = await call({...data, selections: [...data.selections].reverse()});

    assert.equal(second.replayed, true);
    assert.deepEqual(second.recordIds, first.recordIds);
    assert.deepEqual(second.state, first.state);
    assert.equal(second.signaturePath, null);
    assert.equal(reordered.replayed, true);
    assert.deepEqual(reordered.recordIds, first.recordIds);
    assert.equal((await recordsOf(data.clientCaptureId)).length, 3);
  });

  test('AC-DF-109.6 two concurrent calls with one clientCaptureId: one set of records, both answers agree', async () => {
    const pendingId = await seedPending();
    const data = payload(pendingId, [selection('required'), selection('healthData')]);
    const [a, b] = await Promise.all([call(data), call(data)]);
    assert.deepEqual(a.recordIds, b.recordIds);
    assert.deepEqual([a.replayed, b.replayed].sort(), [false, true]);
    assert.equal((await recordsOf(data.clientCaptureId)).length, 2);
  });

  test('TC-06-RC-06 same clientCaptureId with other content or from another trainer -> already-exists idempotency.keyReused', async () => {
    const pendingId = await seedPending();
    const data = payload(pendingId, [selection('required'), selection('healthData')]);
    await call(data);

    await rejectsWith(call({...data, selections: [selection('required')]}),
      'already-exists', 'idempotency.keyReused', ['clientCaptureId']);
    await rejectsWith(call(data, trainer(TRAINER_B)), 'already-exists', 'idempotency.keyReused', ['clientCaptureId']);
    assert.equal((await recordsOf(data.clientCaptureId)).length, 2);
  });

  test('auth: no auth -> unauthenticated auth.required; member token -> permission-denied auth.notTrainer', async () => {
    const pendingId = await seedPending();
    const data = payload(pendingId, [selection('required')]);
    await rejectsWith(call(data, null), 'unauthenticated', 'auth.required');
    await rejectsWith(call(data, {uid: 'synthMember0001', token: {}}), 'permission-denied', 'auth.notTrainer');
    await assertNothingWritten(data);
  });

  test('TC-109-06 not the pending owner -> permission-denied member.pendingNotOwned, nothing written', async () => {
    const pendingId = await seedPending({trainerId: TRAINER_B});
    const data = payload(pendingId, [selection('required'), selection('healthData')]);
    await rejectsWith(call(data), 'permission-denied', 'member.pendingNotOwned', ['memberKey.pendingMemberId']);
    await assertNothingWritten(data);
  });

  test('V11 missing or no longer pending member -> not-found member.notFound, nothing written', async () => {
    const missing = payload(newPendingId(), [selection('required')]);
    await rejectsWith(call(missing), 'not-found', 'member.notFound', ['memberKey.pendingMemberId']);
    await assertNothingWritten(missing);

    for (const status of ['cancelled', 'promoted', 'expired']) {
      const data = payload(await seedPending({status}), [selection('required')]);
      await rejectsWith(call(data), 'not-found', 'member.notFound', ['memberKey.pendingMemberId']);
      await assertNothingWritten(data);
    }
  });

  test('TC-109-07 AC-DF-109.5 draft, retired, missing or other-type document version -> failed-precondition, nothing written', async () => {
    const wrongVersions = [
      selection('healthData', 'healthData--draft-9'),      // status draft
      selection('bodyImaging', 'bodyImaging--retired-0'),  // status retired
      selection('healthData', 'healthData--9.9'),          // no such document
      selection('healthData', DOC.required),               // published, but for ①
    ];
    for (const wrong of wrongVersions) {
      const data = payload(await seedPending(), [selection('required'), wrong]);
      await rejectsWith(call(data), 'failed-precondition', 'consent.documentNotPublished',
        ['selections[1].documentVersion']);
      await assertNothingWritten(data);
    }
  });

  test('V8 ② and ③ with ① neither in the request nor in the stored state -> failed-precondition consent.requiredFirst', async () => {
    const data = payload(await seedPending(), [selection('bodyImaging'), selection('healthData')]);
    await rejectsWith(call(data), 'failed-precondition', 'consent.requiredFirst', ['selections[1].consentType']);
    await assertNothingWritten(data);
  });
});

describe('test consent document publishing on the Firestore emulator', () => {
  test('publishing again changes nothing; a different text under a published ID is refused and nothing is written', async () => {
    const documents = buildTestConsentDocuments(loadDeck());
    const again = await publishConsentDocuments(db, documents);
    assert.deepEqual(again, {created: [], unchanged: documents.map((d) => d.id)});

    const stored = (await db.doc(`consentDocumentVersions/${DOC.healthData}`).get()).data();
    assert.equal(stored.status, 'published');
    assert.ok(stored.publishedAt instanceof Timestamp);

    const changed = documents.map((d) => (d.id === DOC.healthData ? {...d, data: {...d.data, purpose: 'SYNTH changed'}} : d));
    const newId = {id: 'research--test-1', data: {...documents[0].data, consentType: 'research'}};
    await assert.rejects(publishConsentDocuments(db, [...changed, newId]), PublishError);
    assert.equal((await db.doc(`consentDocumentVersions/${DOC.healthData}`).get()).get('purpose'), stored.purpose);
    assert.equal((await db.doc('consentDocumentVersions/research--test-1').get()).exists, false);
  });
});

describe('recordConsent through the Functions emulator', {skip: !authHost && 'needs the Auth and Functions emulators'}, () => {
  let idToken;

  async function idTokenFor(uid) {
    const auth = getAuth(app);
    const email = `${uid.toLowerCase()}@example.invalid`;
    try {
      await auth.updateUser(uid, {email, password: PASSWORD});
    } catch {
      await auth.createUser({uid, email, password: PASSWORD});
    }
    await auth.setCustomUserClaims(uid, {trainer: true});
    const response = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
      {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({email, password: PASSWORD, returnSecureToken: true}),
      },
    );
    const body = await response.json();
    assert.equal(response.status, 200);
    return body.idToken;
  }

  async function callHttp(data, token) {
    const response = await fetch(`http://${functionHost}/${projectId}/asia-northeast3/recordConsent`, {
      method: 'POST',
      headers: {'content-type': 'application/json', ...(token ? {authorization: `Bearer ${token}`} : {})},
      body: JSON.stringify({data}),
    });
    return {status: response.status, body: await response.json()};
  }

  before(async () => {
    idToken = await idTokenFor(TRAINER_A);
  });

  test('AC-DF-109.1 trainer ID token: the callable writes the records and returns {result: {ok: true, ...}}', async () => {
    const pendingId = await seedPending();
    const data = payload(pendingId, [selection('required'), selection('healthData'), selection('bodyImaging')]);
    const {status, body} = await callHttp(data, idToken);
    assert.equal(status, 200, JSON.stringify(body));
    assert.equal(body.result.ok, true);
    assert.equal(body.result.replayed, false);
    assert.equal(body.result.recordIds.length, 3);
    assert.deepEqual(Object.keys(body.result.state), ['required', 'healthData', 'bodyImaging']);
    assert.equal((await recordsOf(data.clientCaptureId)).length, 3);
    assert.equal((await db.doc(`memberConsentStates/${pendingId}`).get()).get('healthData.granted'), true);
  });

  test('errors carry the V1-06 §3.5 shape: status, message key and details', async () => {
    const data = payload(await seedPending({trainerId: TRAINER_B}), [selection('required')]);
    const unauthenticated = await callHttp(data, null);
    assert.equal(unauthenticated.status, 401);
    assert.equal(unauthenticated.body.error.status, 'UNAUTHENTICATED');
    assert.equal(unauthenticated.body.error.message, 'auth.required');

    const notOwned = await callHttp(data, idToken);
    assert.equal(notOwned.status, 403);
    assert.deepEqual(notOwned.body.error, {
      status: 'PERMISSION_DENIED',
      message: 'member.pendingNotOwned',
      details: {
        messageKey: 'member.pendingNotOwned', retryable: false, fields: ['memberKey.pendingMemberId'], violations: [],
      },
    });
    await assertNothingWritten(data);
  });
});
