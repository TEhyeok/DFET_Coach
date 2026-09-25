'use strict';

// DF-037 shared module tests.
// callable.js: the adapter moved from index.js:32-48 to src/shared/callable.js must keep the
// legacy (data, context) contract exactly (AC-DF-037.2 "호출 계약").

const assert = require('node:assert/strict');
const test = require('node:test');
const {callable, functions} = require('../../src/shared/callable');

function recordingHandler() {
  const calls = [];
  const handler = (data, context) => {
    calls.push({data, context});
    return {success: true};
  };
  return {calls, handler};
}

const request = Object.freeze({
  data: Object.freeze({email: 'synthMember0001@example.invalid'}),
  auth: Object.freeze({uid: 'synthAdmin', token: {admin: true}}),
  rawRequest: {headers: {}},
  acceptsStreaming: false,
});

test('AC-DF-037.2 adapter passes request.data as data and only {auth} as context', async () => {
  for (const register of [
    (h) => callable(h),
    (h) => callable(h, {region: 'asia-northeast3'}),
    (h) => functions.https.onCall(h),
    (h) => functions.region('asia-northeast3').https.onCall(h),
  ]) {
    const {calls, handler} = recordingHandler();
    const fn = register(handler);
    assert.deepEqual(await fn.run(request), {success: true});
    assert.equal(calls.length, 1);
    assert.equal(calls[0].data, request.data);
    assert.deepEqual(Object.keys(calls[0].context), ['auth']);
    assert.equal(calls[0].context.auth, request.auth);
  }
});

test('AC-DF-037.2 adapter keeps legacy region behaviour: none by default, explicit when chained', () => {
  const {handler} = recordingHandler();
  assert.equal(functions.https.onCall(handler).__endpoint.region, undefined);
  assert.deepEqual(
    functions.region('asia-northeast3').https.onCall(handler).__endpoint.region,
    ['asia-northeast3']
  );
  assert.ok(functions.https.onCall(handler).__endpoint.callableTrigger);
});

test('AC-DF-037.2 adapter re-exports the v2 HttpsError used by legacy callables', () => {
  const error = new functions.https.HttpsError('invalid-argument', 'x');
  assert.equal(error.code, 'invalid-argument');
  assert.equal(error.httpErrorCode.status, 400);
});

// ---------------------------------------------------------------------------------------------
// region.js (AC-DF-037.1, TC-DF037-02)

const {FieldValue} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');
const {
  FIRESTORE_TRIGGER_REGION,
  REGION,
  SCHEDULE_TIME_ZONE,
  callableV2,
  firestoreTrigger,
  scheduled,
} = require('../../src/shared/region');

test('TC-DF037-02 AC-DF-037.1 REGION is asia-northeast3 and the trigger region is a named constant (ASM-P0-10)', () => {
  assert.equal(REGION, 'asia-northeast3');
  assert.equal(FIRESTORE_TRIGGER_REGION, 'asia-northeast3');
  assert.equal(SCHEDULE_TIME_ZONE, 'Asia/Seoul');
});

test('TC-DF037-02 AC-DF-037.1 callableV2 registers onCall in asia-northeast3 with the (data, context) contract', async () => {
  const {calls, handler} = recordingHandler();
  const fn = callableV2(handler, {memory: '512MiB'});
  assert.deepEqual(fn.__endpoint.region, ['asia-northeast3']);
  assert.ok(fn.__endpoint.callableTrigger);
  assert.equal(fn.__endpoint.availableMemoryMb, 512);
  await fn.run(request);
  assert.equal(calls[0].data, request.data);
  assert.deepEqual(calls[0].context, {auth: request.auth});
});

test('TC-DF037-02 AC-DF-037.1 firestoreTrigger registers onDocumentWritten in FIRESTORE_TRIGGER_REGION', () => {
  const fn = firestoreTrigger('soap_notes/{noteId}', () => null);
  assert.deepEqual(fn.__endpoint.region, [FIRESTORE_TRIGGER_REGION]);
  assert.equal(fn.__endpoint.eventTrigger.eventType, 'google.cloud.firestore.document.v1.written');
  assert.deepEqual(fn.__endpoint.eventTrigger.eventFilterPathPatterns, {document: 'soap_notes/{noteId}'});
});

test('TC-DF037-02 AC-DF-037.1 scheduled registers onSchedule in asia-northeast3, Asia/Seoul', () => {
  const fn = scheduled('0 3 * * *', () => null, {timeoutSeconds: 540});
  assert.deepEqual(fn.__endpoint.region, ['asia-northeast3']);
  assert.equal(fn.__endpoint.scheduleTrigger.schedule, '0 3 * * *');
  assert.equal(fn.__endpoint.scheduleTrigger.timeZone, 'Asia/Seoul');
  assert.equal(fn.__endpoint.timeoutSeconds, 540);
});

test('TC-DF037-02 AC-DF-037.1 wrappers refuse a caller-supplied region and bad arguments', () => {
  const noop = () => null;
  assert.throws(() => callableV2(noop, {region: 'us-central1'}), TypeError);
  assert.throws(() => firestoreTrigger('a/{id}', noop, {region: 'us-central1'}), TypeError);
  assert.throws(() => scheduled('0 3 * * *', noop, {region: 'asia-northeast3'}), TypeError);
  assert.throws(() => callableV2('not a function'), TypeError);
  assert.throws(() => firestoreTrigger('', noop), TypeError);
  assert.throws(() => scheduled('', noop), TypeError);
  assert.throws(() => callableV2(noop, null), TypeError);
});

// ---------------------------------------------------------------------------------------------
// errors.js (AC-DF-037.3, TC-DF037-03)

const {STANDARD_CODES, authRequired, fail, ok} = require('../../src/shared/errors');

function captureFailure(fn) {
  try {
    fn();
  } catch (error) {
    return error;
  }
  assert.fail('expected a throw');
}

test('TC-DF037-03 AC-DF-037.3 the six standard codes are fixed', () => {
  assert.deepEqual([...STANDARD_CODES], [
    'invalid-argument',
    'permission-denied',
    'failed-precondition',
    'not-found',
    'already-exists',
    'resource-exhausted',
  ]);
  assert.ok(Object.isFrozen(STANDARD_CODES));
});

test('TC-DF037-03 AC-DF-037.3 fail throws HttpsError with the message key in message and details', () => {
  for (const code of STANDARD_CODES) {
    const error = captureFailure(() => fail(code, 'member.notAssigned'));
    assert.ok(error instanceof HttpsError, code);
    assert.equal(error.code, code);
    assert.equal(error.message, 'member.notAssigned');
    assert.deepEqual(error.details, {
      messageKey: 'member.notAssigned',
      retryable: code === 'resource-exhausted',
      fields: [],
      violations: [],
    });
  }
  const withFields = captureFailure(() => fail('invalid-argument', 'common.invalidArgument', {
    fields: ['selections[1].consentType'],
  }));
  assert.deepEqual(withFields.details.fields, ['selections[1].consentType']);
});

test('TC-DF037-03 AC-DF-037.3 fail with a non-standard code is a developer error, not an HttpsError', () => {
  for (const code of ['internal', 'unauthenticated', 'aborted', 'unavailable', 'unknown', 'not_found', '', undefined]) {
    const error = captureFailure(() => fail(code, 'common.internal'));
    assert.ok(error instanceof TypeError, String(code));
    assert.ok(!(error instanceof HttpsError), String(code));
  }
});

test('TC-DF037-03 AC-DF-037.3 fail rejects Korean sentences and free-form details', () => {
  assert.throws(() => fail('not-found', '회원을 찾을 수 없습니다.'), TypeError);
  assert.throws(() => fail('not-found', 'notAKey'), TypeError);
  assert.throws(() => fail('not-found', 'member.notFound', {email: 'synthMember0001@example.invalid'}), TypeError);
  assert.throws(() => fail('not-found', 'member.notFound', {fields: 'uid'}), TypeError);
  assert.throws(() => fail('not-found', 'member.notFound', ['fields']), TypeError);
});

test('TC-DF037-03 AC-DF-037.3 ok returns {ok: true, ...payload}', () => {
  assert.deepEqual(ok(), {ok: true});
  assert.deepEqual(ok({replayed: false, summaryId: 'SYNTHsummary00000001'}), {
    ok: true,
    replayed: false,
    summaryId: 'SYNTHsummary00000001',
  });
  assert.throws(() => ok({ok: false}), TypeError);
  assert.throws(() => ok(null), TypeError);
  assert.throws(() => ok([1]), TypeError);
});

test('TC-DF037-03 authRequired is the only unauthenticated error and uses auth.required', () => {
  const error = authRequired();
  assert.ok(error instanceof HttpsError);
  assert.equal(error.code, 'unauthenticated');
  assert.equal(error.message, 'auth.required');
  assert.equal(error.details.messageKey, 'auth.required');
});

// ---------------------------------------------------------------------------------------------
// auth.js (V1-06 §3.3)

const {requireAdminClaim, requireAuth, requireTrainer} = require('../../src/shared/auth');

function assertCode(fn, code, messageKey) {
  const error = captureFailure(fn);
  assert.ok(error instanceof HttpsError);
  assert.equal(error.code, code);
  assert.equal(error.message, messageKey);
}

test('DF-037 requireAuth returns the uid or throws unauthenticated/auth.required', () => {
  assert.equal(requireAuth({auth: {uid: 'synthMember0001', token: {}}}), 'synthMember0001');
  for (const context of [undefined, null, {}, {auth: null}, {auth: {token: {}}}, {auth: {uid: ''}}]) {
    assertCode(() => requireAuth(context), 'unauthenticated', 'auth.required');
  }
});

test('DF-037 requireTrainer needs token.trainer === true', () => {
  assert.equal(requireTrainer({auth: {uid: 'synthTrainerA', token: {trainer: true}}}), 'synthTrainerA');
  for (const token of [{}, {trainer: 'true'}, {trainer: 1}, {admin: true}]) {
    assertCode(() => requireTrainer({auth: {uid: 'synthTrainerA', token}}), 'permission-denied', 'auth.notTrainer');
  }
  assertCode(() => requireTrainer({}), 'unauthenticated', 'auth.required');
});

test('DF-037 requireAdminClaim needs token.admin === true (same claim as verifyAdmin, ADR-018)', () => {
  assert.equal(requireAdminClaim({auth: {uid: 'synthAdmin', token: {admin: true}}}), 'synthAdmin');
  for (const token of [{}, {admin: 'true'}, {role: 'admin'}, {trainer: true}]) {
    assertCode(() => requireAdminClaim({auth: {uid: 'synthAdmin', token}}), 'permission-denied', 'auth.notAdmin');
  }
  assertCode(() => requireAdminClaim({auth: null}), 'unauthenticated', 'auth.required');
});

// ---------------------------------------------------------------------------------------------
// audit.js (AC-DF-037.4, TC-DF037-04) with fake writers; no Firestore needed.

const {AUDIT_COLLECTION, writeAuditEntry} = require('../../src/shared/audit');

function fakeDb() {
  let autoId = 0;
  const created = [];
  const db = {
    created,
    batch() {
      throw new Error('not used');
    },
    collection(name) {
      return {
        doc(id) {
          const ref = {path: `${name}/${id ?? `auto${++autoId}`}`};
          ref.create = async (data) => {
            created.push({ref, data});
          };
          return ref;
        },
      };
    },
  };
  return db;
}

function fakeTransaction() {
  const writes = [];
  return {
    writes,
    get() {
      throw new Error('not used');
    },
    create(ref, data) {
      writes.push({op: 'create', ref, data});
      return this;
    },
  };
}

const assignmentEntry = Object.freeze({
  action: 'member.assignment.update',
  actorUid: 'synthAdmin',
  actorRole: 'admin',
  targetCollection: 'trainers',
  targetId: 'synthTrainerA',
  memberUid: 'synthMember0001',
  metadata: Object.freeze({handover: true, mode: 'reassign', trainerUid: 'synthTrainerA'}),
});
const assignmentKeys = ['handover', 'mode', 'trainerUid'];

test('TC-DF037-04 AC-DF-037.4 writes one auditLogs document with at and createdAt serverTimestamp in the transaction', () => {
  const db = fakeDb();
  const tx = fakeTransaction();
  const ref = writeAuditEntry(tx, assignmentEntry, {db, allowedKeys: assignmentKeys});
  assert.equal(tx.writes.length, 1);
  const {op, ref: writtenRef, data} = tx.writes[0];
  assert.equal(op, 'create');
  assert.equal(writtenRef, ref);
  assert.match(ref.path, new RegExp(`^${AUDIT_COLLECTION}/auto\\d+$`));
  assert.ok(data.at.isEqual(FieldValue.serverTimestamp()));
  assert.ok(data.createdAt.isEqual(FieldValue.serverTimestamp()));
  assert.deepEqual(
    {...data, at: 'serverTimestamp', createdAt: 'serverTimestamp'},
    {
      action: 'member.assignment.update',
      actorUid: 'synthAdmin',
      actorRole: 'admin',
      targetCollection: 'trainers',
      targetId: 'synthTrainerA',
      memberUid: 'synthMember0001',
      metadata: {handover: true, mode: 'reassign', trainerUid: 'synthTrainerA'},
      at: 'serverTimestamp',
      createdAt: 'serverTimestamp',
      schemaVersion: 1,
    }
  );
  assert.equal(db.created.length, 0);
});

test('TC-DF037-04 AC-DF-037.4 metadata key outside allowedKeys throws and writes nothing', () => {
  const db = fakeDb();
  const tx = fakeTransaction();
  assert.throws(
    () => writeAuditEntry(tx, {...assignmentEntry, metadata: {handover: true, memberName: 'x'}}, {
      db,
      allowedKeys: assignmentKeys,
    }),
    /metadata key 'memberName' is not allowed/
  );
  assert.equal(tx.writes.length, 0);
});

test('TC-DF037-04 AC-DF-037.4 allowedKeys is required until DF-033; registry (AUDIT_ACTIONS) replaces it', () => {
  const db = fakeDb();
  const tx = fakeTransaction();
  assert.throws(() => writeAuditEntry(tx, assignmentEntry, {db}), /allowedKeys/);
  const registry = [{action: 'member.assignment.update', metadataKeys: assignmentKeys}];
  writeAuditEntry(tx, assignmentEntry, {db, registry});
  assert.equal(tx.writes.length, 1);
  assert.throws(
    () => writeAuditEntry(tx, {...assignmentEntry, action: 'unregistered.action'}, {db, registry}),
    /not registered/
  );
  assert.throws(
    () => writeAuditEntry(tx, {...assignmentEntry, metadata: {handover: true, extra: 1}}, {db, registry}),
    /metadata key 'extra'/
  );
  assert.throws(
    () => writeAuditEntry(tx, assignmentEntry, {db, registry, allowedKeys: assignmentKeys}),
    /not both/
  );
  assert.equal(tx.writes.length, 1);
});

test('TC-DF037-04 AC-DF-037.4 metadata values: short strings, booleans, integers, integer count maps only', () => {
  const db = fakeDb();
  const tx = fakeTransaction();
  const base = {
    action: 'dataDeleted',
    actorUid: null,
    actorRole: 'system',
    targetCollection: 'pendingMembers',
    targetId: 'SYNTHpending00000001',
    memberUid: null,
  };
  const allowedKeys = ['reason', 'counts', 'pendingMember', 'note'];
  writeAuditEntry(tx, {...base, metadata: {reason: 'pendingExpired', counts: {soap_notes: 2}, pendingMember: true}}, {
    db,
    allowedKeys,
  });
  assert.equal(tx.writes.length, 1);
  for (const metadata of [
    {counts: {soap_notes: 1.5}},
    {counts: {soap_notes: -1}},
    {counts: {nested: {a: 1}}},
    {reason: 72.5},
    {reason: ['a']},
    {reason: null},
    {note: 'x'.repeat(65)},
    {note: ''},
  ]) {
    assert.throws(() => writeAuditEntry(tx, {...base, metadata}, {db, allowedKeys}), TypeError, JSON.stringify(metadata));
  }
  assert.equal(tx.writes.length, 1);
});

test('TC-DF037-04 AC-DF-037.4 required fields and actorRole are validated', () => {
  const db = fakeDb();
  const tx = fakeTransaction();
  const opts = {db, allowedKeys: assignmentKeys};
  for (const patch of [
    {action: ''},
    {actorRole: 'integration'},
    {actorRole: undefined},
    {actorUid: ''},
    {targetCollection: undefined},
    {targetId: ''},
    {memberUid: undefined},
    {metadata: []},
  ]) {
    assert.throws(() => writeAuditEntry(tx, {...assignmentEntry, ...patch}, opts), TypeError, JSON.stringify(patch));
  }
  assert.equal(tx.writes.length, 0);
});

test('TC-DF037-04 AC-DF-037.4 deterministic docId, Firestore writer and writer validation', async () => {
  const db = fakeDb();
  const tx = fakeTransaction();
  const soapEntry = {
    action: 'soapFinalized',
    actorUid: 'synthTrainerA',
    actorRole: 'trainer',
    targetCollection: 'soap_notes',
    targetId: 'SYNTHnote00000000001',
    memberUid: 'synthMember0001',
  };
  const ref = writeAuditEntry(tx, soapEntry, {db, allowedKeys: [], docId: 'soapFinalized_SYNTHnote00000000001'});
  assert.equal(ref.path, 'auditLogs/soapFinalized_SYNTHnote00000000001');
  assert.deepEqual(tx.writes[0].data.metadata, {});

  const dbRef = await writeAuditEntry(db, soapEntry, {allowedKeys: []});
  assert.equal(db.created.length, 1);
  assert.equal(db.created[0].ref, dbRef);
  assert.ok(db.created[0].data.at.isEqual(FieldValue.serverTimestamp()));

  assert.throws(() => writeAuditEntry(tx, soapEntry, {allowedKeys: []}), /options\.db is required/);
  assert.throws(() => writeAuditEntry({}, soapEntry, {db, allowedKeys: []}), /writer must be/);
  assert.throws(() => writeAuditEntry(null, soapEntry, {db, allowedKeys: []}), /writer must be/);
  assert.throws(() => writeAuditEntry(tx, soapEntry, {db, allowedKeys: [], docId: ''}), /docId/);
});
