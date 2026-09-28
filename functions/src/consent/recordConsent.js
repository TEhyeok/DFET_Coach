'use strict';

// recordConsent callable (DF-109, V1-06 §6.2, V1-05 §4.11-§4.12, ADR-011). MVP scope (DEC-22, DF-109 '### MVP 범위'):
// a trainer records ①②③ grants for a pending member it created. Records carry signaturePath null; uid members,
// the memberApp channel, ④⑤, withdraw, signature PNG, audit entries and post-commit processing come later
// (validateRequest.assertMvpScope rejects them with failed-precondition 'consent.unsupportedInMvp').
//
// Auth and the request come first (requireTrainer, validateRequest, the MVP gate), then one transaction, all reads
// before writes (V1-06 §3.8, §6.2.4 order: permission and existence before the idempotency check):
//   1. pendingMembers/{p}. Checks: V11 (exists), V2 (member.pendingNotOwned), V11 (status 'pending'). A replay runs
//      only after these, so a caller who lost the member (or the trainer claim) never gets its current state back.
//   2. consentRecords where clientCaptureId == X. Found: same caller (recordedBy), member key, channel and selections
//      -> replay the stored result ({replayed: true}, no writes); anything else -> already-exists 'idempotency.keyReused'.
//   3. memberConsentStates/{p}, consentDocumentVersions/{v} for each selection. Checks: V5
//      (consent.documentNotPublished), V8 (consent.requiredFirst).
//   4. Writes: one consentRecords document per selection (auto ID, recordedAt = one server Timestamp for the call),
//      then memberConsentStates/{p} merged with derive(prev, newRecords).
// recordIds and the state keys follow the consent type order (required, healthData, bodyImaging, sharing,
// research), so a replay answers with the same recordIds whatever order the client listed the selections in.

const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const {HttpsError} = require('firebase-functions/v2/https');
const {requireTrainer} = require('../shared/auth');
const {fail, internalError, ok} = require('../shared/errors');
const {callableV2} = require('../shared/region');
const {CONSENT_TYPES, derive, toResponseState} = require('./core/deriveConsentState');
const {assertMvpScope, validateRequest} = require('./core/validateRequest');

const SCHEMA_VERSION = 1;

function byConsentType(a, b) {
  return CONSENT_TYPES.indexOf(a.consentType) - CONSENT_TYPES.indexOf(b.consentType);
}

function selectionKey({consentType, action, documentVersion}) {
  return `${consentType}|${action}|${documentVersion}`;
}

// Stored records of one capture match the request (V1-06 §6.2.5), and the caller is the one who recorded them,
// so another trainer cannot read a capture's result by replaying its key.
function sameCapture(stored, request, uid) {
  const {memberUid = null, pendingMemberId = null} = request.memberKey;
  const sameOwner = stored.every((record) => record.recordedBy === uid
    && record.channel === request.channel
    && (pendingMemberId !== null
      ? record.pendingMemberId === pendingMemberId
      : record.pendingMemberId === null && record.subjectUid === memberUid));
  const storedKeys = new Set(stored.map(selectionKey));
  return sameOwner
    && storedKeys.size === request.selections.length
    && request.selections.every((selection) => storedKeys.has(selectionKey(selection)));
}

async function recordConsentCore({db, now, auth, data}) {
  const uid = requireTrainer({auth});
  const request = validateRequest(data, now().toMillis());
  assertMvpScope(request);

  const {pendingMemberId} = request.memberKey;
  const memberField = 'memberKey.pendingMemberId';
  // Keep the request index for error fields; work in consent type order.
  const selections = request.selections.map((selection, index) => ({...selection, index})).sort(byConsentType);
  const records = db.collection('consentRecords');
  const pendingRef = db.collection('pendingMembers').doc(pendingMemberId);
  const stateRef = db.collection('memberConsentStates').doc(pendingMemberId);
  const documentRefs = selections.map((s) => db.collection('consentDocumentVersions').doc(s.documentVersion));

  return db.runTransaction(async (tx) => {
    const pendingSnap = await tx.get(pendingRef);
    if (!pendingSnap.exists) fail('not-found', 'member.notFound', {fields: [memberField]});                // V11
    if (pendingSnap.get('trainerId') !== uid) {
      fail('permission-denied', 'member.pendingNotOwned', {fields: [memberField]});                       // V2
    }
    if (pendingSnap.get('status') !== 'pending') fail('not-found', 'member.notFound', {fields: [memberField]});

    const previous = await tx.get(records.where('clientCaptureId', '==', request.clientCaptureId));
    if (!previous.empty) {
      const stored = previous.docs.map((snap) => ({recordId: snap.id, ...snap.data()})).sort(byConsentType);
      if (!sameCapture(stored, request, uid)) {
        fail('already-exists', 'idempotency.keyReused', {fields: ['clientCaptureId']});
      }
      const state = await tx.get(stateRef);
      return ok({
        replayed: true,
        recordIds: stored.map((record) => record.recordId),
        state: toResponseState(state.data()),
        signaturePath: stored[0].signaturePath ?? null,
      });
    }

    const [stateSnap, ...documentSnaps] = await tx.getAll(stateRef, ...documentRefs);
    documentSnaps.forEach((snap, i) => {                                                                   // V5
      const selection = selections[i];
      if (!snap.exists || snap.get('status') !== 'published' || snap.get('consentType') !== selection.consentType) {
        fail('failed-precondition', 'consent.documentNotPublished', {
          fields: [`selections[${selection.index}].documentVersion`],
        });
      }
    });

    const prev = stateSnap.exists ? stateSnap.data() : null;
    const grantsRequired = selections.some((s) => s.consentType === 'required' && s.action === 'grant');
    const holdsRequired = prev !== null && prev.required !== undefined && prev.required.granted === true;
    const needsRequired = selections.find((s) => s.consentType !== 'required' && s.action === 'grant');
    if (needsRequired && !grantsRequired && !holdsRequired) {                                              // V8
      fail('failed-precondition', 'consent.requiredFirst', {fields: [`selections[${needsRequired.index}].consentType`]});
    }

    const recordedAt = now();
    const capturedAt = request.capturedAtMillis === null ? null : Timestamp.fromMillis(request.capturedAtMillis);
    const written = selections.map(({consentType, action, documentVersion}) => {
      const ref = records.doc();
      tx.create(ref, {
        subjectUid: null,
        pendingMemberId,
        consentType,
        action,
        documentVersion,
        channel: request.channel,
        recordedAt,
        recordedBy: uid,
        capturedAt,
        signaturePath: null,
        reconfirmedAt: null,
        reconfirmOf: null,
        clientCaptureId: request.clientCaptureId,
        schemaVersion: SCHEMA_VERSION,
      });
      return {recordId: ref.id, consentType, action, documentVersion, recordedAt};
    });
    const next = derive(prev, written);
    tx.set(stateRef, {...next, updatedAt: recordedAt, schemaVersion: SCHEMA_VERSION}, {merge: true});

    return ok({
      replayed: false,
      recordIds: written.map((record) => record.recordId),
      state: toResponseState(next),
      signaturePath: null,
    });
  });
}

// Anything that is not an HttpsError becomes internal/'common.internal'. The log carries no request data, uid or
// path (NFR-10, V1-06 §3.10): only the error's own code.
async function handler(data, context) {
  try {
    return await recordConsentCore({db: getFirestore(), now: () => Timestamp.now(), auth: context.auth, data});
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error('dfet.consent.recordFailed', {
      fn: 'recordConsent',
      event: 'dfet.consent.recordFailed',
      code: error && error.code !== undefined ? String(error.code) : null,
    });
    throw internalError();
  }
}

module.exports = {
  recordConsentCore,
  recordConsent: callableV2(handler, {memory: '512MiB'}),
};
