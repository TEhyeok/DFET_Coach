'use strict';

// DF-037 export snapshot. The expected file was generated from the pre-DF-037 index.js and committed
// before the callable adapter moved to src/shared/callable.js (AC-DF-037.2, TC-DF037-01).
// Regenerate it only when a story intentionally changes a legacy export, and say so in the PR.

const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');
const {describeExport, describeExports} = require('./_exportSnapshot');

const SNAPSHOT = require('./__snapshots__/exports.json');

// Tests describe the deploy manifest, which must not depend on the emulator-only secret switch.
delete process.env.FUNCTIONS_EMULATOR;
const indexExports = require(path.join(__dirname, '..', '..', 'index.js'));

const LEGACY_DEFAULT_REGION_CALLABLES = [
  'setAdminClaim',
  'removeAdminClaim',
  'listAllUsers',
  'getUserDetails',
  'deleteUserData',
  'setTrainerClaim',
  'removeTrainerClaim',
  'assignMemberToTrainer',
  'removeMemberFromTrainer',
];
const LEGACY_SEOUL_CALLABLES = ['deleteOwnAccount', 'toggleCommunityLike', 'addCommunityComment'];
const LEGACY_SEOUL_HTTPS = ['clinicalApi'];
const LEGACY_EXPORTS = [
  ...LEGACY_DEFAULT_REGION_CALLABLES,
  ...LEGACY_SEOUL_CALLABLES,
  ...LEGACY_SEOUL_HTTPS,
];

// Admin-gated legacy callables that validate `data` before touching Firebase Admin APIs.
// Calling them with an admin token and empty data proves `data` still arrives as the first argument.
const ADMIN_CALLABLES_VALIDATING_DATA = [
  'setAdminClaim',
  'removeAdminClaim',
  'getUserDetails',
  'deleteUserData',
  'setTrainerClaim',
  'removeTrainerClaim',
  'assignMemberToTrainer',
  'removeMemberFromTrainer',
];

const synthAdminAuth = {uid: 'synthAdminA', token: {admin: true}};
const synthMemberAuth = {uid: 'synthMember0001', token: {}};

async function assertHttpsError(promise, code) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, code, `expected HttpsError ${code}, got ${error.code}: ${error.message}`);
    assert.equal(typeof error.httpErrorCode?.status, 'number');
    return true;
  });
}

test('TC-DF037-01 AC-DF-037.2 snapshot covers the 13 legacy exports (9 default + 3 Seoul onCall + 1 onRequest)', () => {
  assert.deepEqual(Object.keys(SNAPSHOT).sort(), [...LEGACY_EXPORTS].sort());
  for (const name of LEGACY_DEFAULT_REGION_CALLABLES) {
    assert.equal(SNAPSHOT[name].kind, 'callable', name);
    assert.equal(SNAPSHOT[name].region, 'us-central1', name);
  }
  for (const name of LEGACY_SEOUL_CALLABLES) {
    assert.equal(SNAPSHOT[name].kind, 'callable', name);
    assert.equal(SNAPSHOT[name].region, 'asia-northeast3', name);
  }
  assert.equal(SNAPSHOT.clinicalApi.kind, 'https');
  assert.equal(SNAPSHOT.clinicalApi.region, 'asia-northeast3');
});

test('TC-DF037-01 AC-DF-037.2 legacy exports keep name, kind, region and options', () => {
  const current = describeExports(indexExports);
  for (const name of LEGACY_EXPORTS) {
    assert.ok(name in current, `legacy export ${name} is missing`);
    assert.deepEqual(current[name], SNAPSHOT[name], `legacy export ${name} changed`);
  }
});

test('TC-DF037-01 AC-DF-037.2 every export is a Cloud Function with an endpoint', () => {
  for (const [name, fn] of Object.entries(indexExports)) {
    assert.notEqual(describeExport(fn), null, `${name} has no __endpoint`);
  }
});

test('TC-DF037-01 AC-DF-037.2 legacy callables keep the (data, context) contract: no auth -> unauthenticated', async () => {
  for (const name of [...LEGACY_DEFAULT_REGION_CALLABLES, ...LEGACY_SEOUL_CALLABLES]) {
    await assertHttpsError(indexExports[name].run({data: {}}), 'unauthenticated');
  }
});

test('TC-DF037-01 AC-DF-037.2 legacy admin callables read context.auth.token.admin: non-admin -> permission-denied', async () => {
  for (const name of LEGACY_DEFAULT_REGION_CALLABLES) {
    await assertHttpsError(
      indexExports[name].run({data: {}, auth: synthMemberAuth}),
      'permission-denied'
    );
  }
});

test('TC-DF037-01 AC-DF-037.2 legacy callables receive request.data as data: empty payload -> invalid-argument', async () => {
  for (const name of ADMIN_CALLABLES_VALIDATING_DATA) {
    await assertHttpsError(
      indexExports[name].run({data: {}, auth: synthAdminAuth}),
      'invalid-argument'
    );
  }
  for (const name of ['toggleCommunityLike', 'addCommunityComment']) {
    await assertHttpsError(
      indexExports[name].run({data: {}, auth: synthMemberAuth}),
      'invalid-argument'
    );
  }
});
