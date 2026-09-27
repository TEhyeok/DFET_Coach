'use strict';

// DF-109 / DEC-22: test-member MVP only. No signatures, uid subjects, withdrawal, or deferred APIs.
const {createHash} = require('node:crypto');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {requireTrainer} = require('../shared/auth');
const {fail, ok} = require('../shared/errors');
const {callableV2} = require('../shared/region');
const {writeAuditEntry} = require('../shared/audit');
const {derive} = require('./core/deriveConsentState');
const {MVP_TYPES, validateRequest, validateCaptureTime} = require('./core/validateRequest');

// The first normal consentRecord doubles as the transaction's idempotency lock. Its ID is scoped
// to the caller and capture, independent of member/selection, so two conflicting requests cannot
// both commit even when their memberConsentStates documents differ. No new collection is needed.
// Other records use Firestore auto IDs; all IDs remain 20 alphanumeric characters (V1-04 §9.1).
function firstRecordId(uid, captureId) {
  return createHash('sha256').update(JSON.stringify([uid, captureId])).digest('base64url')
    .replace(/[-_]/g, '').slice(0, 20);
}

function responseState(state) {
  const result = {};
  for (const type of MVP_TYPES) {
    const value = state[type];
    if (value) result[type] = {...value, updatedAt: value.updatedAt.toDate().toISOString()};
  }
  return result;
}

function sameCapture(records, request, uid) {
  if (records.length !== request.selections.length) return false;
  return request.selections.every(selection => records.some(record =>
    record.recordedBy === uid && record.subjectUid === null &&
    record.pendingMemberId === request.memberKey.pendingMemberId &&
    record.channel === request.channel && record.consentType === selection.consentType &&
    record.action === selection.action && record.documentVersion === selection.documentVersion &&
    (record.capturedAt?.toMillis() ?? null) === (request.capturedAt?.getTime() ?? null)
  ));
}

async function core(db, _storage, auth, data, now = () => Timestamp.now()) {
  const uid = requireTrainer({auth});
  const request = validateRequest(data);
  const records = db.collection('consentRecords');
  const firstRef = records.doc(firstRecordId(uid, request.clientCaptureId));
  const pendingRef = db.collection('pendingMembers').doc(request.memberKey.pendingMemberId);
  const stateRef = db.collection('memberConsentStates').doc(request.memberKey.pendingMemberId);

  return db.runTransaction(async tx => {
    const pending = await tx.get(pendingRef);
    if (!pending.exists || pending.data().trainerId !== uid || pending.data().status !== 'pending') {
      fail('permission-denied', 'member.pendingNotOwned');
    }
    const first = await tx.get(firstRef);
    const state = await tx.get(stateRef);
    if (first.exists) {
      // Single-field query needs no composite index. Only this caller's records are compared or
      // returned; another trainer may legitimately use the same client-generated capture ID.
      const capture = await tx.get(records.where('clientCaptureId', '==', request.clientCaptureId));
      const existing = capture.docs.map(snap => ({id: snap.id, ...snap.data()}))
        .filter(record => record.recordedBy === uid);
      if (!sameCapture(existing, request, uid)) fail('already-exists', 'idempotency.keyReused');
      existing.sort((a, b) => MVP_TYPES.indexOf(a.consentType) - MVP_TYPES.indexOf(b.consentType));
      return ok({replayed: true, recordIds: existing.map(record => record.id),
        state: responseState(state.data() || {}), signaturePath: null});
    }

    for (const selection of request.selections) {
      const version = await tx.get(db.collection('consentDocumentVersions').doc(selection.documentVersion));
      if (!version.exists || version.data().status !== 'published' ||
        version.data().consentType !== selection.consentType) {
        fail('failed-precondition', 'consent.documentNotPublished');
      }
    }
    const serverTime = now();
    const recordedAt = serverTime instanceof Date ? Timestamp.fromDate(serverTime) : serverTime;
    validateCaptureTime(request.capturedAt, recordedAt.toDate());
    if (state.data()?.required?.granted !== true &&
      !request.selections.some(selection => selection.consentType === 'required')) {
      fail('failed-precondition', 'consent.requiredFirst');
    }
    const refs = request.selections.map((_, index) => index === 0 ? firstRef : records.doc());
    const newRecords = request.selections.map((selection, index) => ({
      id: refs[index].id, subjectUid: null, pendingMemberId: request.memberKey.pendingMemberId,
      ...selection, channel: request.channel, recordedAt, recordedBy: uid,
      capturedAt: request.capturedAt ? Timestamp.fromDate(request.capturedAt) : null,
      signaturePath: null, reconfirmOf: null, reconfirmedAt: null,
      clientCaptureId: request.clientCaptureId, schemaVersion: 1,
    }));
    const nextState = derive(state.data() || {}, newRecords);
    for (let index = 0; index < newRecords.length; index += 1) {
      const {id, ...record} = newRecords[index];
      tx.create(refs[index], record);
      writeAuditEntry(tx, {
        action: 'consentChanged', actorUid: uid, actorRole: 'trainer', memberUid: null,
        targetCollection: 'consentRecords', targetId: id,
        metadata: {consentType: record.consentType, action: record.action, channel: record.channel},
      }, {db, allowedKeys: ['consentType', 'action', 'channel']});
    }
    tx.set(stateRef, nextState);
    return ok({replayed: false, recordIds: refs.map(ref => ref.id),
      state: responseState(nextState), signaturePath: null});
  });
}

const handler = callableV2((data, context) => core(getFirestore(), null, context.auth, data), {
  memory: '512MiB',
});

module.exports = {core, handler};
