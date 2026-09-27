'use strict';

// DF-109: real callable + Auth/Firestore emulator, synthetic subjects only. DEC-22 is grant-only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomBytes} = require('node:crypto');
const {after, before, test} = require('node:test');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, serverTimestamp, Timestamp: ClientTimestamp} = require('firebase/firestore');
const {publish, buildDocuments} = require('../../scripts/dev/publish-test-consent-documents');
const {core} = require('../../src/consent/recordConsent');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'demo-dfet';
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const trainerA = 'synthConsentTrainerA';
const trainerB = 'synthConsentTrainerB';
let app;
let db;
let rulesEnv;
const tokens = {};

const selection = consentType => ({consentType, action: 'grant', documentVersion: `${consentType}--mvp-test-1`});
const request = (pendingMemberId, overrides = {}) => ({
  clientCaptureId: `cap_${randomBytes(12).toString('hex')}`, memberKey: {pendingMemberId},
  channel: 'trainerDeviceInPerson', selections: ['required', 'healthData', 'bodyImaging'].map(selection),
  ...overrides,
});

async function pending(owner = trainerA, status = 'pending') {
  const id = `SYNTH${randomBytes(10).toString('hex').slice(0, 15)}`;
  await db.doc(`pendingMembers/${id}`).set({
    trainerId: owner, status, displayName: '가상 동의 테스트 회원', sex: 'unspecified',
    birthYear: 1990, ageConfirmed14: true, schemaVersion: 1,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  return id;
}

async function call(data, uid = trainerA) {
  const response = await fetch(`http://${functionHost}/${projectId}/asia-northeast3/recordConsent`, {
    method: 'POST', headers: {'content-type': 'application/json', ...(uid ? {authorization: `Bearer ${tokens[uid]}`} : {})},
    body: JSON.stringify({data}),
  });
  return {status: response.status, ...(await response.json())};
}

async function noRecords(id) {
  assert.equal((await db.collection('consentRecords').where('pendingMemberId', '==', id).get()).size, 0);
  assert.equal((await db.doc(`memberConsentStates/${id}`).get()).exists, false);
}

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore Emulator is required');
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Auth Emulator is required');
  assert.ok(projectId.startsWith('demo-') || projectId === 'dfet-e2e', 'synthetic emulator project required');
  app = initializeApp({projectId}, 'consent-e2e');
  db = getFirestore(app);
  const auth = getAuth(app);
  for (const uid of [trainerA, trainerB, 'synthConsentMember']) {
    const email = `${uid.toLowerCase()}@example.invalid`;
    const password = 'emulator-only-password';
    try { await auth.createUser({uid, email, password}); }
    catch (error) {
      if (error.code !== 'auth/uid-already-exists' && error.code !== 'auth/email-already-exists') throw error;
      await auth.updateUser(uid, {email, password});
    }
    await auth.setCustomUserClaims(uid, uid === 'synthConsentMember' ? {} : {trainer: true});
    const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
      method: 'POST', headers: {'content-type': 'application/json'},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    });
    assert.equal(response.status, 200);
    tokens[uid] = (await response.json()).idToken;
  }
  await publish(db);
  await db.doc('appConfig/features').set({soapV2: true, bodyComposition: true}, {merge: true});
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  rulesEnv = await initializeTestEnvironment({projectId, firestore: {
    host, port: Number(port), rules: fs.readFileSync(path.resolve(__dirname, '../../../firestore.rules'), 'utf8'),
  }});
});

after(async () => {
  if (rulesEnv) await rulesEnv.cleanup();
  if (app) await deleteApp(app);
});

test('TC-109-05/09 AC-DF-109.1/2/7 DEC-22 callable grants three types, locks client writes, enables SOAP', async () => {
  const id = await pending();
  const client = rulesEnv.authenticatedContext(trainerA, {trainer: true}).firestore();
  const soap = {
    schemaVersion: 2, trainerId: trainerA, authorUid: trainerA, pendingMemberId: id,
    sessionDate: ClientTimestamp.fromMillis(Date.now() - 1000), status: 'draft',
    quickNote: '합성 기록', legalNature: 'coachingRecord', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(client, `soap_notes/${id}`), soap));
  await assertFails(setDoc(doc(client, `memberConsentStates/${id}`), {healthData: {granted: true}}));
  await assertFails(setDoc(doc(client, `consentRecords/${id}`), {pendingMemberId: id, action: 'grant'}));
  const payload = request(id, {capturedAt: new Date().toISOString()});
  const response = await call(payload);
  assert.equal(response.status, 200, JSON.stringify(response));
  assert.equal(response.result.ok, true);
  assert.equal(response.result.replayed, false);
  assert.equal(response.result.signaturePath, null);
  assert.equal(response.result.recordIds.length, 3);
  const records = await Promise.all(response.result.recordIds.map(recordId => db.doc(`consentRecords/${recordId}`).get()));
  const time = records[0].data().recordedAt.toMillis();
  for (const snap of records) {
    const value = snap.data();
    assert.equal(value.pendingMemberId, id);
    assert.equal(value.subjectUid, null);
    assert.equal(value.recordedBy, trainerA);
    assert.equal(value.signaturePath, null);
    assert.equal(value.channel, 'trainerDeviceInPerson');
    assert.equal(value.recordedAt.toMillis(), time);
    assert.equal(value.capturedAt.toDate().toISOString(), payload.capturedAt);
  }
  const state = (await db.doc(`memberConsentStates/${id}`).get()).data();
  for (const type of ['required', 'healthData', 'bodyImaging']) {
    assert.equal(state[type].granted, true);
    assert.equal(response.result.state[type].updatedAt, state[type].updatedAt.toDate().toISOString());
  }
  const audits = await db.collection('auditLogs').where('targetId', 'in', response.result.recordIds).get();
  assert.equal(audits.size, 3);
  for (const snap of audits.docs) {
    const value = snap.data();
    assert.equal(value.action, 'consentChanged');
    assert.equal(value.memberUid, null);
    assert.deepEqual(Object.keys(value.metadata).sort(), ['action', 'channel', 'consentType']);
  }
  await assertSucceeds(setDoc(doc(client, `soap_notes/${id}`), soap));
});

test('TC-109-06 AC-DF-109.4 rejects missing auth, non-trainer, non-owner and cancelled subjects without writes', async () => {
  const id = await pending();
  assert.equal((await call(request(id), null)).status, 401);
  assert.equal((await call(request(id), 'synthConsentMember')).status, 403);
  assert.equal((await call(request(id), trainerB)).status, 403);
  await noRecords(id);
  const cancelled = await pending(trainerA, 'cancelled');
  assert.equal((await call(request(cancelled))).status, 403);
  await noRecords(cancelled);
});

test('TC-109-07 AC-DF-109.5 absent, retired and mismatched published versions have no side effects', async () => {
  await db.doc('consentDocumentVersions/required--retired-synth').set({consentType: 'required', status: 'retired'});
  for (const version of ['required--missing-synth', 'required--retired-synth', 'healthData--mvp-test-1']) {
    const id = await pending();
    const response = await call(request(id, {selections: [{...selection('required'), documentVersion: version}]}));
    assert.equal(response.status, 400, JSON.stringify(response));
    assert.equal(response.error.details.messageKey, 'consent.documentNotPublished');
    await noRecords(id);
  }
});

test('TC-109-08 AC-DF-109.6 concurrent identical captures commit once and reordered selections replay', async () => {
  const id = await pending();
  const payload = request(id);
  const responses = await Promise.all([call(payload), call(payload), call(payload)]);
  for (const response of responses) assert.equal(response.status, 200, JSON.stringify(response));
  assert.equal(responses.filter(response => !response.result.replayed).length, 1);
  assert.deepEqual(responses[0].result.recordIds, responses[1].result.recordIds);
  const replay = await call({...payload, selections: [...payload.selections].reverse()});
  assert.deepEqual(replay.result.recordIds, responses[0].result.recordIds);
  const saved = await db.collection('consentRecords').where('pendingMemberId', '==', id).get();
  assert.equal(saved.size, 3);
  const audits = await db.collection('auditLogs').where('targetId', 'in', replay.result.recordIds).get();
  assert.equal(audits.size, 3);
  const changed = await call({...payload, selections: [selection('required')]});
  assert.equal(changed.status, 409);
  assert.equal(changed.error.details.messageKey, 'idempotency.keyReused');
});

test('AC-DF-109.6 capture IDs are caller-scoped and conflicting same-caller members cannot both commit', async () => {
  const a = await pending();
  const b = await pending();
  const payload = request(a, {selections: [selection('required')]});
  const outcomes = await Promise.all([call(payload), call({...payload, memberKey: {pendingMemberId: b}})]);
  assert.deepEqual(outcomes.map(value => value.status).sort(), [200, 409]);
  const other = await pending(trainerB);
  const otherResponse = await call({...payload, memberKey: {pendingMemberId: other}}, trainerB);
  assert.equal(otherResponse.status, 200, JSON.stringify(otherResponse));
  assert.notDeepEqual(otherResponse.result.recordIds, outcomes.find(value => value.status === 200).result.recordIds);
});

test('AC-DF-109.5 required consent precedes optional grants; omitted types retain their prior state', async () => {
  const id = await pending();
  const first = await call(request(id, {selections: [selection('healthData')]}));
  assert.equal(first.error.details.messageKey, 'consent.requiredFirst');
  await noRecords(id);
  assert.equal((await call(request(id, {selections: [selection('required')]}))).status, 200);
  assert.equal((await call(request(id, {selections: [selection('healthData')]}))).status, 200);
  const after = await call(request(id, {selections: [selection('bodyImaging')]}));
  assert.equal(after.result.state.healthData.granted, true);
  assert.equal(after.result.state.required.granted, true);
});

test('AC-DF-109.6 committed captures replay even after the offline capture window and retired document', async () => {
  const id = await pending();
  const instant = new Date();
  const documentVersion = 'required--replay-synth';
  await db.doc(`consentDocumentVersions/${documentVersion}`).set({consentType: 'required', status: 'published'});
  const payload = request(id, {capturedAt: instant.toISOString(), selections: [{...selection('required'), documentVersion}]});
  const auth = {uid: trainerA, token: {trainer: true}};
  const first = await core(db, null, auth, payload, () => instant);
  await db.doc(`consentDocumentVersions/${documentVersion}`).update({status: 'retired'});
  const replay = await core(db, null, auth, payload, () => new Date(instant.getTime() + 8 * 86400000));
  assert.equal(replay.replayed, true);
  assert.deepEqual(replay.recordIds, first.recordIds);
  const stale = await pending();
  await assert.rejects(core(db, null, auth, {...payload, clientCaptureId: `${payload.clientCaptureId}_new`,
    memberKey: {pendingMemberId: stale}, selections: [selection('required')]}, () => new Date(instant.getTime() + 8 * 86400000)),
  error => error.code === 'invalid-argument' && error.details.messageKey === 'consent.captureTimeInvalid');
  await noRecords(stale);
});

test('AC-DF-109.5 published test notices are immutable and publication is idempotent', async () => {
  const before = (await db.doc('consentDocumentVersions/required--mvp-test-1').get()).data();
  assert.deepEqual(await publish(db), {created: 0, unchanged: 3});
  const after = (await db.doc('consentDocumentVersions/required--mvp-test-1').get()).data();
  assert.ok(after.publishedAt.isEqual(before.publishedAt));
  assert.deepEqual(after.items, buildDocuments()['required--mvp-test-1'].items);
});
