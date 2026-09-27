'use strict';

// DF-109 AC-DF-109.9 (export metadata) and the checks recordConsent makes before it touches Firestore, called through
// the registered v2 function. Database paths are covered by test/e2e/recordConsent.e2e.test.js.

const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');

delete process.env.FUNCTIONS_EMULATOR;
const {recordConsent} = require(path.join(__dirname, '..', '..', '..', 'index.js'));

const trainerAuth = {uid: 'synthTrainerA', token: {trainer: true}};

function validData(overrides = {}) {
  return {
    clientCaptureId: 'cap_SYNTH_0001',
    memberKey: {pendingMemberId: 'SYNTHpending00000001'},
    channel: 'trainerDeviceInPerson',
    selections: [{consentType: 'required', action: 'grant', documentVersion: 'required--test-1'}],
    ...overrides,
  };
}

async function rejectsWith(promise, code, messageKey) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, code);
    assert.equal(error.message, messageKey);
    assert.equal(error.details.messageKey, messageKey);
    return true;
  });
}

test('AC-DF-109.9 recordConsent is a v2 onCall in asia-northeast3 with 512MiB (V1-06 §6.2)', () => {
  const endpoint = recordConsent.__endpoint;
  assert.ok(endpoint.callableTrigger);
  assert.equal(endpoint.platform, 'gcfv2');
  assert.deepEqual(endpoint.region, ['asia-northeast3']);
  assert.equal(endpoint.availableMemoryMb, 512);
});

test('no auth -> unauthenticated auth.required; no trainer claim -> permission-denied auth.notTrainer', async () => {
  await rejectsWith(recordConsent.run({data: validData()}), 'unauthenticated', 'auth.required');
  await rejectsWith(recordConsent.run({data: validData(), auth: {uid: 'synthMember0001', token: {}}}),
    'permission-denied', 'auth.notTrainer');
});

test('request checks and the MVP gate answer before any database read', async () => {
  await rejectsWith(recordConsent.run({data: {}, auth: trainerAuth}), 'invalid-argument', 'common.invalidArgument');
  await rejectsWith(recordConsent.run({data: validData({memberKey: {memberUid: 'synthMember0001'}}), auth: trainerAuth}),
    'failed-precondition', 'consent.unsupportedInMvp');
});
