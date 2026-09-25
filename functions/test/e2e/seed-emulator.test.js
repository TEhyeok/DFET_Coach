'use strict';

// DF-042 TC-DF042-01 (e2e, emulator): after seeding, claims, synthTrainerA.memberIds (2) and the
// 8 feature flags exist (AC-DF-042.1), and a second run yields the same result (AC-DF-042.4).
// Needs the Auth and Firestore emulators:
//   firebase emulators:exec --only auth,functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"

const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const path = require('node:path');
const {after, before, test} = require('node:test');
const {deleteApp, initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');

const SCRIPT = path.resolve(__dirname, '../../scripts/dev/seed-emulator.js');
const FIXTURE = path.resolve(__dirname, '../fixtures/emulator-seed.v1.json');
const {EMULATOR_ONLY_PASSWORD, loadSeed} = require(SCRIPT);

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'demo-dfet';
const seed = loadSeed(FIXTURE);
let app;
let auth;
let db;

function runSeed() {
  return execFileSync(process.execPath, [SCRIPT, '--seed', FIXTURE], {
    env: {...process.env, GCLOUD_PROJECT: projectId},
    encoding: 'utf8',
  });
}

/** Seed users and documents with server timestamps replaced by a marker (they differ per run). */
async function snapshot() {
  const users = {};
  for (const {uid} of seed.auth) {
    const record = await auth.getUser(uid);
    users[uid] = {
      email: record.email,
      displayName: record.displayName,
      emailVerified: record.emailVerified,
      disabled: record.disabled,
      customClaims: record.customClaims || {},
    };
  }
  const normalize = (value) => {
    if (value instanceof Timestamp) return '<timestamp>';
    if (Array.isArray(value)) return value.map(normalize);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.keys(value).sort().map((k) => [k, normalize(value[k])]));
    }
    return value;
  };
  const docs = {};
  for (const {path: docPath} of seed.firestore) {
    const snap = await db.doc(docPath).get();
    docs[docPath] = snap.exists ? normalize(snap.data()) : null;
  }
  return {users, docs};
}

async function signInWithPassword(email) {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const response = await fetch(
    `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({email, password: EMULATOR_ONLY_PASSWORD, returnSecureToken: true}),
    },
  );
  return {status: response.status, body: await response.json()};
}

before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore Emulator is required');
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Auth Emulator is required');
  app = initializeApp({projectId}, 'seed-emulator-e2e');
  auth = getAuth(app);
  db = getFirestore(app);
});

after(async () => {
  if (app) await deleteApp(app);
});

test('TC-DF042-01 AC-DF-042.1 AC-DF-042.4 seed creates claims, memberIds, members, consent, 8 flags and is idempotent', async () => {
  const firstLog = runSeed();
  assert.match(firstLog, /auth 6 .*firestore 7 documents/);
  assert.doesNotMatch(firstLog, /@|synth/i, 'log carries counts only');
  const first = await snapshot();

  // Accounts and claims.
  assert.deepEqual(first.users.synthTrainerA.customClaims, {trainer: true});
  assert.deepEqual(first.users.synthTrainerB.customClaims, {trainer: true});
  assert.deepEqual(first.users.synthAdmin.customClaims, {admin: true});
  for (const n of ['0001', '0002', '0003']) {
    assert.deepEqual(first.users[`synthMember${n}`].customClaims, {});
  }
  for (const [uid, user] of Object.entries(first.users)) {
    assert.equal(user.email, `${uid.toLowerCase()}@example.invalid`);
  }
  const signIn = await signInWithPassword('synthTrainerA@example.invalid');
  assert.equal(signIn.status, 200, JSON.stringify(signIn.body));
  assert.equal(signIn.body.localId, 'synthTrainerA');

  // Assignment, members, consent, flags.
  assert.deepEqual(first.docs['trainers/synthTrainerA'].memberIds, ['synthMember0001', 'synthMember0002']);
  assert.equal(first.docs['trainers/synthTrainerA'].memberIds.length, 2);
  assert.deepEqual(first.docs['trainers/synthTrainerB'].memberIds, []);
  assert.deepEqual(
    ['0001', '0002', '0003'].map((n) => first.docs[`users/synthMember${n}`].displayName),
    ['가상회원 가', '가상회원 나', '가상회원 다'],
  );
  assert.equal(first.docs['users/synthMember0001'].trainerId, 'synthTrainerA');
  assert.equal(first.docs['users/synthMember0002'].trainerId, 'synthTrainerA');
  const consent = first.docs['memberConsentStates/synthMember0001'];
  for (const type of ['required', 'healthData', 'bodyImaging']) {
    assert.equal(consent[type].granted, true, type);
    assert.equal(consent[type].updatedAt, '<timestamp>');
  }
  const flags = first.docs['appConfig/features'];
  assert.equal(Object.keys(flags).length, 8);
  assert.deepEqual(flags, {
    blood: false, bodyAssessment: false, bodyComposition: true, gut: false,
    insights: false, lidarBeta: false, memberShare: false, soapV2: true,
  });

  // AC-DF-042.4: drift the seeded data, rerun, and get the same result back (overwrite, no merge).
  await db.doc('trainers/synthTrainerA').update({memberIds: ['synthMember0003'], stray: true});
  await db.doc('appConfig/features').update({soapV2: false, extraFlag: true});
  await auth.setCustomUserClaims('synthTrainerB', {admin: true});
  runSeed();
  const second = await snapshot();
  assert.deepEqual(second, first);
});
