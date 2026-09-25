#!/usr/bin/env node
'use strict';

/**
 * DF-042 emulator-only synthetic seed (V1-10 §5.4, ASM-10-24).
 *
 *   firebase emulators:start --only auth,firestore,storage,functions --project demo-dfet
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099 \
 *     node functions/scripts/dev/seed-emulator.js --seed functions/test/fixtures/emulator-seed.v1.json
 *
 * Safety (AC-DF-042.2):
 * - The emulator guard runs before anything else. Without FIRESTORE_EMULATOR_HOST and
 *   FIREBASE_AUTH_EMULATOR_HOST the script writes nothing and exits with code 2.
 * - The project ID must be a `demo-*` ID or one of the CI emulator IDs; anything else exits 2.
 * - No credential is ever loaded (GOOGLE_APPLICATION_CREDENTIALS is dropped), so the Admin SDK
 *   can only reach the emulators. There is no flag that turns the guard off.
 *
 * Idempotent (AC-DF-042.4): Auth users are created or updated to the seed values (claims are
 * replaced, not merged) and every Firestore document is overwritten with set() (no merge).
 */

const fs = require('node:fs');
const path = require('node:path');

const EXIT_GUARD = 2;
const EXIT_USAGE = 1;
const DEFAULT_PROJECT_ID = 'demo-dfet';
const BATCH_LIMIT = 400;
/** Emulator-only project IDs used by CI (V1-10 §4.2). `demo-*` never reaches real resources. */
const EMULATOR_PROJECT_IDS = Object.freeze(['dfet-e2e', 'dfet-rules-test']);
/** Fixed synthetic password (DF-042 implementation note). Emulator Auth only. */
const EMULATOR_ONLY_PASSWORD = 'emulator-only-password';
/** RFC 2606 reserved domain: mail is never delivered (V1-10 §5.2). */
const SYNTHETIC_EMAIL_DOMAIN = '@example.invalid';
const REQUIRED_EMULATOR_ENV = Object.freeze(['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']);

class SeedError extends Error {
  constructor(message, exitCode = EXIT_USAGE) {
    super(message);
    this.exitCode = exitCode;
  }
}

/** Returns the names of the required emulator variables that are missing or blank. */
function missingEmulatorEnv(env) {
  return REQUIRED_EMULATOR_ENV.filter((name) => !String(env[name] || '').trim());
}

function isEmulatorProjectId(projectId) {
  return /^demo-[a-z0-9-]+$/.test(projectId) || EMULATOR_PROJECT_IDS.includes(projectId);
}

function parseArgs(argv) {
  const args = {seed: null, project: null};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--seed' || arg === '--project') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new SeedError(`${arg} needs a value`);
      args[arg.slice(2)] = value;
      i += 1;
    } else {
      throw new SeedError(`unknown argument: ${arg}`);
    }
  }
  if (!args.seed) throw new SeedError('usage: seed-emulator.js --seed <file.json> [--project <demo-id>]');
  return args;
}

/** --project, then the emulator-provided project (emulators:exec sets GCLOUD_PROJECT), then demo-dfet. */
function resolveProjectId(args, env) {
  return args.project || env.GCLOUD_PROJECT || env.GOOGLE_CLOUD_PROJECT || DEFAULT_PROJECT_ID;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/** Validates the seed file shape. Throws SeedError with the first problem found. */
function validateSeed(seed) {
  if (!isPlainObject(seed)) throw new SeedError('seed must be a JSON object');
  const allowed = ['_seed', 'auth', 'firestore'];
  for (const key of Object.keys(seed)) {
    if (!allowed.includes(key)) throw new SeedError(`unknown top-level key: ${key}`);
  }
  if (!isPlainObject(seed._seed) || typeof seed._seed.id !== 'string') {
    throw new SeedError('_seed.id is required');
  }
  if (!Array.isArray(seed.auth) || !Array.isArray(seed.firestore)) {
    throw new SeedError('auth and firestore must be arrays');
  }
  const uids = new Set();
  for (const user of seed.auth) {
    if (!isPlainObject(user) || typeof user.uid !== 'string' || !/^(synth|SYNTH)[A-Za-z0-9]+$/.test(user.uid)) {
      throw new SeedError('auth[].uid must be a synth/SYNTH synthetic ID');
    }
    if (uids.has(user.uid)) throw new SeedError(`duplicate auth uid: ${user.uid}`);
    uids.add(user.uid);
    if (typeof user.email !== 'string' || !user.email.endsWith(SYNTHETIC_EMAIL_DOMAIN)) {
      throw new SeedError(`auth[${user.uid}].email must use ${SYNTHETIC_EMAIL_DOMAIN}`);
    }
    if (user.claims !== undefined && !isPlainObject(user.claims)) {
      throw new SeedError(`auth[${user.uid}].claims must be an object`);
    }
  }
  const paths = new Set();
  for (const doc of seed.firestore) {
    if (!isPlainObject(doc) || typeof doc.path !== 'string' || !isPlainObject(doc.data)) {
      throw new SeedError('firestore[] entries need {path, data}');
    }
    const segments = doc.path.split('/');
    if (segments.length % 2 !== 0 || segments.some((s) => !s)) {
      throw new SeedError(`firestore path is not a document path: ${doc.path}`);
    }
    if (paths.has(doc.path)) throw new SeedError(`duplicate firestore path: ${doc.path}`);
    paths.add(doc.path);
  }
  return seed;
}

function loadSeed(seedPath) {
  let seed;
  try {
    seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  } catch (error) {
    throw new SeedError(`cannot read seed ${seedPath}: ${error.message}`);
  }
  return validateSeed(seed);
}

/**
 * Decodes the fixture type tags (P0 fixture contract): {"$ts": ISO} → Timestamp,
 * {"$serverTimestamp": true} → FieldValue.serverTimestamp(). Everything else is copied.
 */
function decodeValue(value, {Timestamp, FieldValue}) {
  if (Array.isArray(value)) return value.map((item) => decodeValue(item, {Timestamp, FieldValue}));
  if (!isPlainObject(value)) return value;
  const keys = Object.keys(value);
  if (keys.length === 1 && keys[0] === '$ts') {
    const date = new Date(value.$ts);
    if (typeof value.$ts !== 'string' || Number.isNaN(date.getTime())) {
      throw new SeedError(`invalid $ts value: ${JSON.stringify(value.$ts)}`);
    }
    return Timestamp.fromDate(date);
  }
  if (keys.length === 1 && keys[0] === '$serverTimestamp') {
    if (value.$serverTimestamp !== true) throw new SeedError('$serverTimestamp must be true');
    return FieldValue.serverTimestamp();
  }
  const out = {};
  for (const key of keys) {
    if (key.startsWith('$')) throw new SeedError(`unknown type tag: ${key}`);
    out[key] = decodeValue(value[key], {Timestamp, FieldValue});
  }
  return out;
}

async function upsertAuthUser(auth, user) {
  const properties = {
    email: user.email,
    emailVerified: true,
    password: EMULATOR_ONLY_PASSWORD,
    displayName: user.displayName || null,
    disabled: false,
  };
  let created = false;
  try {
    await auth.updateUser(user.uid, properties);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await auth.createUser({uid: user.uid, ...properties});
    created = true;
  }
  // Replace (not merge) so a rerun yields exactly the seed claims.
  await auth.setCustomUserClaims(user.uid, user.claims && Object.keys(user.claims).length ? user.claims : null);
  return created;
}

async function seedEmulator(seed, projectId) {
  // Never let a credential file steer the Admin SDK away from the emulators.
  delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getAuth} = require('firebase-admin/auth');
  const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

  const app = initializeApp({projectId}, `seed-emulator-${process.pid}`);
  try {
    const auth = getAuth(app);
    const db = getFirestore(app);
    let created = 0;
    for (const user of seed.auth) {
      if (await upsertAuthUser(auth, user)) created += 1;
    }
    // Decode everything first so a bad tag fails before any document is written.
    const writes = seed.firestore.map((doc) => [db.doc(doc.path), decodeValue(doc.data, {Timestamp, FieldValue})]);
    for (let i = 0; i < writes.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      for (const [ref, data] of writes.slice(i, i + BATCH_LIMIT)) batch.set(ref, data);
      await batch.commit();
    }
    return {authUsers: seed.auth.length, authCreated: created, documents: seed.firestore.length};
  } finally {
    await deleteApp(app);
  }
}

async function main(argv = process.argv.slice(2), env = process.env) {
  // 1. Emulator guard first: nothing is parsed, read or loaded before it passes.
  const missing = missingEmulatorEnv(env);
  if (missing.length) {
    throw new SeedError(`emulator only: ${missing.join(', ')} not set. Nothing was written.`, EXIT_GUARD);
  }
  const args = parseArgs(argv);
  const projectId = resolveProjectId(args, env);
  if (!isEmulatorProjectId(projectId)) {
    throw new SeedError(
      `emulator only: project "${projectId}" is not a demo-* or CI emulator project. Nothing was written.`,
      EXIT_GUARD,
    );
  }
  const seedPath = path.resolve(args.seed);
  const seed = loadSeed(seedPath);
  const result = await seedEmulator(seed, projectId);
  // Counts only (no IDs, names or emails in the log).
  console.log(
    `[seed-emulator] ${seed._seed.id} → ${projectId}: auth ${result.authUsers} ` +
      `(created ${result.authCreated}), firestore ${result.documents} documents`,
  );
  return result;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`[seed-emulator] ${error.message}`);
    process.exit(error instanceof SeedError ? error.exitCode : EXIT_USAGE);
  });
}

module.exports = {
  EMULATOR_ONLY_PASSWORD,
  EXIT_GUARD,
  SeedError,
  decodeValue,
  isEmulatorProjectId,
  loadSeed,
  main,
  missingEmulatorEnv,
  parseArgs,
  resolveProjectId,
  validateSeed,
};
