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
  data: Object.freeze({email: 'synth-member-0001@example.test'}),
  auth: Object.freeze({uid: 'synthAdminA', token: {admin: true}}),
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
