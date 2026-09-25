'use strict';

// DF-042 emulator seed guard and fixture tests (no emulator needed).
// TC-DF042-02: without FIRESTORE_EMULATOR_HOST or FIREBASE_AUTH_EMULATOR_HOST the script exits 2
// and writes nothing (AC-DF-042.2). The e2e half (TC-DF042-01) is test/e2e/seed-emulator.test.js.

const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const SCRIPT = path.resolve(__dirname, '../../../scripts/dev/seed-emulator.js');
const FIXTURE = path.resolve(__dirname, '../../fixtures/emulator-seed.v1.json');
const seedModule = require(SCRIPT);

const EMULATOR_VARS = [
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST',
  'GCLOUD_PROJECT',
  'GOOGLE_CLOUD_PROJECT',
];

function cleanEnv(extra = {}) {
  const env = {...process.env};
  for (const name of EMULATOR_VARS) delete env[name];
  return {...env, ...extra};
}

function runScript(args, env) {
  return spawnSync(process.execPath, [SCRIPT, ...args], {env, encoding: 'utf8', timeout: 20000});
}

const FIRESTORE = {FIRESTORE_EMULATOR_HOST: '127.0.0.1:18080'};
const AUTH = {FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:19099'};

test('TC-DF042-02 AC-DF-042.2 no emulator variables → exit 2, nothing written', () => {
  const result = runScript(['--seed', FIXTURE], cleanEnv());
  assert.equal(result.status, 2, result.stderr);
  assert.match(result.stderr, /FIRESTORE_EMULATOR_HOST/);
  assert.match(result.stderr, /FIREBASE_AUTH_EMULATOR_HOST/);
  assert.match(result.stderr, /Nothing was written/);
  assert.equal(result.stdout, '');
});

test('TC-DF042-02 AC-DF-042.2 only one emulator variable → exit 2', () => {
  for (const extra of [FIRESTORE, AUTH, {...FIRESTORE, FIREBASE_AUTH_EMULATOR_HOST: '  '}]) {
    const result = runScript(['--seed', FIXTURE], cleanEnv(extra));
    assert.equal(result.status, 2, `${JSON.stringify(extra)}: ${result.stderr}`);
    assert.equal(result.stdout, '');
  }
});

test('TC-DF042-02 AC-DF-042.2 guard runs before argument parsing', () => {
  const result = runScript([], cleanEnv());
  assert.equal(result.status, 2, result.stderr);
});

test('TC-DF042-02 AC-DF-042.2 non-demo project → exit 2 even with emulator variables', () => {
  for (const project of ['some-real-project', 'dfet-production-like']) {
    const viaFlag = runScript(['--seed', FIXTURE, '--project', project], cleanEnv({...FIRESTORE, ...AUTH}));
    assert.equal(viaFlag.status, 2, viaFlag.stderr);
    const viaEnv = runScript(['--seed', FIXTURE], cleanEnv({...FIRESTORE, ...AUTH, GCLOUD_PROJECT: project}));
    assert.equal(viaEnv.status, 2, viaEnv.stderr);
  }
});

test('TC-DF042-02 AC-DF-042.2 guard rejects before firebase-admin is loaded', async () => {
  await assert.rejects(seedModule.main(['--seed', FIXTURE], {}), (error) => {
    assert.equal(error.exitCode, seedModule.EXIT_GUARD);
    return true;
  });
  const loaded = Object.keys(require.cache).filter((key) => key.includes(`${path.sep}firebase-admin${path.sep}`));
  assert.deepEqual(loaded, []);
});

test('AC-DF-042.2 script has no credential loading path', () => {
  const source = fs.readFileSync(SCRIPT, 'utf8');
  assert.doesNotMatch(source, /credential\s*[.:]|applicationDefault|serviceAccount|service-account/);
  assert.doesNotMatch(source, /--(force|prod|production|no-guard)/);
});

test('AC-DF-042.2 project ID allow-list is demo-* or CI emulator IDs only', () => {
  for (const id of ['demo-dfet', 'demo-x1', 'dfet-e2e', 'dfet-rules-test']) {
    assert.equal(seedModule.isEmulatorProjectId(id), true, id);
  }
  for (const id of ['', 'demo-', 'demo-DFET', 'dfet', 'my-project', 'dfet-e2e-prod']) {
    assert.equal(seedModule.isEmulatorProjectId(id), false, id);
  }
  assert.equal(seedModule.resolveProjectId({project: null}, {}), 'demo-dfet');
  assert.equal(seedModule.resolveProjectId({project: null}, {GCLOUD_PROJECT: 'dfet-e2e'}), 'dfet-e2e');
  assert.equal(seedModule.resolveProjectId({project: 'demo-a'}, {GCLOUD_PROJECT: 'dfet-e2e'}), 'demo-a');
});

test('AC-DF-042.1 base seed file has the V1-10 §5.4 accounts, assignments, consent and 8 flags', () => {
  const seed = seedModule.loadSeed(FIXTURE);
  const users = Object.fromEntries(seed.auth.map((u) => [u.uid, u]));
  assert.deepEqual(Object.keys(users).sort(), [
    'synthAdmin', 'synthMember0001', 'synthMember0002', 'synthMember0003', 'synthTrainerA', 'synthTrainerB',
  ]);
  assert.deepEqual(users.synthTrainerA.claims, {trainer: true});
  assert.deepEqual(users.synthTrainerB.claims, {trainer: true});
  assert.deepEqual(users.synthAdmin.claims, {admin: true});
  for (const user of seed.auth) {
    assert.equal(user.email, `${user.uid}@example.invalid`);
  }
  const docs = Object.fromEntries(seed.firestore.map((d) => [d.path, d.data]));
  assert.deepEqual(docs['trainers/synthTrainerA'].memberIds, ['synthMember0001', 'synthMember0002']);
  assert.deepEqual(
    ['0001', '0002', '0003'].map((n) => docs[`users/synthMember${n}`].displayName),
    ['가상회원 가', '가상회원 나', '가상회원 다'],
  );
  const consent = docs['memberConsentStates/synthMember0001'];
  for (const type of ['required', 'healthData', 'bodyImaging']) {
    assert.equal(consent[type].granted, true, type);
    assert.equal(consent[type].documentVersion, `${type}--1.0`);
    assert.match(consent[type].recordId, /^SYNTH[A-Za-z0-9]{15}$/);
  }
  assert.deepEqual(docs['appConfig/features'], {
    gut: false, blood: false, insights: false,
    soapV2: true, bodyComposition: true, bodyAssessment: false, memberShare: false, lidarBeta: false,
  });
});

test('seed validation rejects real email domains, non-synth IDs and bad paths', () => {
  const base = () => ({_seed: {id: 't'}, auth: [], firestore: []});
  const cases = [
    {...base(), auth: [{uid: 'synthX', email: 'synthX@gmail.com'}]},
    {...base(), auth: [{uid: 'realUser', email: 'realUser@example.invalid'}]},
    {...base(), firestore: [{path: 'users', data: {}}]},
    {...base(), firestore: [{path: 'users//x', data: {}}]},
    {...base(), extra: true},
  ];
  for (const seed of cases) {
    assert.throws(() => seedModule.validateSeed(seed), seedModule.SeedError, JSON.stringify(seed));
  }
});

test('type tags decode to Timestamp and serverTimestamp; unknown tags fail', () => {
  const Timestamp = {fromDate: (d) => ({ts: d.toISOString()})};
  const FieldValue = {serverTimestamp: () => 'SERVER_TS'};
  const decoded = seedModule.decodeValue(
    {a: {$ts: '2026-11-16T01:00:00Z'}, b: {$serverTimestamp: true}, c: [{d: 1}], e: null},
    {Timestamp, FieldValue},
  );
  assert.deepEqual(decoded, {a: {ts: '2026-11-16T01:00:00.000Z'}, b: 'SERVER_TS', c: [{d: 1}], e: null});
  assert.throws(() => seedModule.decodeValue({$bytes: 'AA=='}, {Timestamp, FieldValue}), seedModule.SeedError);
  assert.throws(() => seedModule.decodeValue({$ts: 'not a date'}, {Timestamp, FieldValue}), seedModule.SeedError);
});
