'use strict';

// DF-043 (DEC-19, Q-08, G-09): every Storage access and deploy target names the Seoul bucket.
// TC-DF043-01 appBucket() bucket selection and account deletion buckets, TC-DF043-04 static guards.
// Bucket and project values are read from the code and config under test; this file writes none of them.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {
  SEOUL_STORAGE_BUCKET,
  accountDeletionBuckets,
  appBucket,
  appBucketName,
  deleteAccountMedia,
  isStorageEmulator,
} = require('../../src/shared/storage');

const repoRoot = path.resolve(__dirname, '../../..');
const functionsRoot = path.join(repoRoot, 'functions');
const helperPath = path.join(functionsRoot, 'src/shared/storage.js');

function read(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function walk(dir, accept) {
  const out = [];
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full, accept));
    else if (accept(entry.name)) out.push(full);
  }
  return out;
}

// Records every storage().bucket(...) call of a fake firebase-admin namespace.
function fakeAdmin() {
  const calls = [];
  return {
    calls,
    admin: {
      storage: () => ({
        bucket: (...args) => {
          calls.push(args);
          return {name: args.length === 0 ? '<default>' : args[0]};
        },
      }),
    },
  };
}

// Production project ID, read from the FlutterFire section of firebase.json.
function productionProjectId() {
  const dart = readJson('firebase.json').flutter.platforms.dart;
  const ids = new Set(Object.values(dart).map((config) => config.projectId));
  assert.equal(ids.size, 1, 'firebase.json flutter.platforms.dart must name one project');
  return [...ids][0];
}

function defaultBucketNames(projectId) {
  return [`${projectId}.firebasestorage.app`, `${projectId}.appspot.com`];
}

test('TC-DF043-01 AC-DF-043.1 appBucket() uses the Seoul bucket outside the emulator', () => {
  for (const env of [{}, {FUNCTIONS_EMULATOR: 'false'}, {FIREBASE_STORAGE_EMULATOR_HOST: ''}]) {
    const {admin, calls} = fakeAdmin();
    assert.equal(isStorageEmulator(env), false, JSON.stringify(env));
    assert.equal(appBucketName(env), SEOUL_STORAGE_BUCKET);
    assert.equal(appBucket(admin, env).name, SEOUL_STORAGE_BUCKET);
    assert.deepEqual(calls, [[SEOUL_STORAGE_BUCKET]]);
  }
});

test('TC-DF043-01 AC-DF-043.1 appBucket() keeps the default bucket under the emulator', () => {
  for (const env of [
    {FUNCTIONS_EMULATOR: 'true'},
    {FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:19199'},
    {FUNCTIONS_EMULATOR: 'true', FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:19199'},
  ]) {
    const {admin, calls} = fakeAdmin();
    assert.equal(isStorageEmulator(env), true, JSON.stringify(env));
    assert.equal(appBucketName(env), undefined);
    assert.equal(appBucket(admin, env).name, '<default>');
    assert.deepEqual(calls, [[]], 'emulator path must call bucket() with no name');
  }
});

test('TC-DF043-01 appBucket() reads process.env by default and rejects a missing admin', () => {
  const saved = {
    FUNCTIONS_EMULATOR: process.env.FUNCTIONS_EMULATOR,
    FIREBASE_STORAGE_EMULATOR_HOST: process.env.FIREBASE_STORAGE_EMULATOR_HOST,
  };
  try {
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.FIREBASE_STORAGE_EMULATOR_HOST;
    assert.equal(appBucket(fakeAdmin().admin).name, SEOUL_STORAGE_BUCKET);
    process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:19199';
    assert.equal(appBucket(fakeAdmin().admin).name, '<default>');
  } finally {
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
  assert.throws(() => appBucket(undefined), TypeError);
  assert.throws(() => appBucket({}), TypeError);
});

// Fake firebase-admin namespace whose buckets record deleteFiles/getFiles/delete calls.
function fakeStorageAdmin({failing = new Set()} = {}) {
  const log = [];
  const makeBucket = (name) => ({
    name,
    deleteFiles: async (options) => {
      log.push([name, 'deleteFiles', options.prefix]);
      if (failing.has(name)) throw new Error(`bucket ${name} missing`);
    },
    getFiles: async (options) => {
      log.push([name, 'getFiles', options.prefix]);
      if (failing.has(name)) throw new Error(`bucket ${name} missing`);
      return [[
        {name: 'posts/1_member-a.jpg', delete: async () => log.push([name, 'delete', 'posts/1_member-a.jpg'])},
        {name: 'posts/2_member-b.jpg', delete: async () => log.push([name, 'delete', 'posts/2_member-b.jpg'])},
      ]];
    },
  });
  return {
    log,
    admin: {
      storage: () => ({
        bucket: (...args) => makeBucket(args.length === 0 ? '<default>' : args[0]),
      }),
    },
  };
}

async function quietly(fn) {
  const warn = console.warn;
  const warnings = [];
  console.warn = (...args) => warnings.push(args);
  try {
    await fn();
  } finally {
    console.warn = warn;
  }
  return warnings;
}

test('TC-DF043-01 G-09 account deletion clears the Seoul and the legacy default bucket', async () => {
  const {admin, log} = fakeStorageAdmin();
  assert.deepEqual(accountDeletionBuckets(admin, {}).map((bucket) => bucket.name),
    [SEOUL_STORAGE_BUCKET, '<default>']);
  await deleteAccountMedia(admin, 'member-a', {});
  for (const bucket of [SEOUL_STORAGE_BUCKET, '<default>']) {
    assert.deepEqual(log.filter(([name]) => name === bucket), [
      [bucket, 'deleteFiles', 'requests/member-a/'],
      [bucket, 'getFiles', 'posts/'],
      [bucket, 'delete', 'posts/1_member-a.jpg'],
    ]);
  }
});

test('TC-DF043-01 G-09 account deletion uses one bucket under the emulator', async () => {
  const {admin, log} = fakeStorageAdmin();
  const env = {FUNCTIONS_EMULATOR: 'true'};
  assert.deepEqual(accountDeletionBuckets(admin, env).map((bucket) => bucket.name), ['<default>']);
  await deleteAccountMedia(admin, 'member-a', env);
  assert.deepEqual(log, [
    ['<default>', 'deleteFiles', 'requests/member-a/'],
    ['<default>', 'getFiles', 'posts/'],
    ['<default>', 'delete', 'posts/1_member-a.jpg'],
  ]);
});

test('TC-DF043-01 G-09 a missing bucket does not abort account deletion', async () => {
  const {admin, log} = fakeStorageAdmin({failing: new Set([SEOUL_STORAGE_BUCKET])});
  const warnings = await quietly(() => deleteAccountMedia(admin, 'member-a', {}));
  assert.equal(warnings.length, 2, 'deleteFiles and getFiles failures are logged');
  assert.deepEqual(log.filter(([name]) => name === '<default>'), [
    ['<default>', 'deleteFiles', 'requests/member-a/'],
    ['<default>', 'getFiles', 'posts/'],
    ['<default>', 'delete', 'posts/1_member-a.jpg'],
  ]);

  const broken = {storage: () => { throw new Error('no storage'); }};
  const resolveWarnings = await quietly(() => deleteAccountMedia(broken, 'member-a', {}));
  assert.equal(resolveWarnings.length, 1);
  await assert.rejects(() => deleteAccountMedia(admin, '', {}), TypeError);
});

test('TC-DF043-01 the Seoul bucket is not the project default bucket', () => {
  assert.match(SEOUL_STORAGE_BUCKET, /^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$/);
  assert.equal(defaultBucketNames(productionProjectId()).includes(SEOUL_STORAGE_BUCKET), false);
});

test('TC-DF043-04 AC-DF-043.1 no storage().bucket(...) or getStorage() outside the helper', () => {
  const files = [
    path.join(functionsRoot, 'index.js'),
    ...walk(path.join(functionsRoot, 'src'), (name) => name.endsWith('.js')),
  ].filter((file) => file !== helperPath);
  assert.ok(files.length > 1);
  // Any bucket(...) call (unnamed, `undefined`, an env var, split over lines) and the modular
  // getStorage() entry point must go through src/shared/storage.js.
  const pattern = /\.\s*bucket\s*\(|\bgetStorage\s*\(|require\(\s*['"]firebase-admin\/storage['"]\s*\)/g;
  const offenders = [];
  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    for (const match of text.matchAll(pattern)) {
      const line = text.slice(0, match.index).split('\n').length;
      offenders.push(`${path.relative(repoRoot, file)}:${line}`);
    }
  }
  assert.deepEqual(offenders, [], 'use appBucket() or deleteAccountMedia() from src/shared/storage.js');
});

test('TC-DF043-04 the bucket guard pattern catches multi-line and non-literal forms', () => {
  const pattern = /\.\s*bucket\s*\(|\bgetStorage\s*\(|require\(\s*['"]firebase-admin\/storage['"]\s*\)/;
  for (const sample of [
    'admin.storage().bucket()',
    'admin.storage().bucket(undefined)',
    'admin.storage().bucket(\n)',
    'admin.storage()\n  .bucket(process.env.X)',
    'getStorage().bucket(name)',
    "const {getStorage} = require('firebase-admin/storage');",
  ]) {
    assert.match(sample, pattern, sample);
  }
  assert.doesNotMatch('appBucket(admin).file(p)', pattern);
});

test('TC-DF043-04 AC-DF-043.2 admin_web example and fallback are the Seoul bucket', () => {
  const example = read('admin_web/.env.example');
  const match = example.match(/^NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=(.*)$/m);
  assert.ok(match, '.env.example must set NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET');
  assert.equal(match[1].trim(), SEOUL_STORAGE_BUCKET);

  const adminTs = read('admin_web/lib/firebase-admin.ts');
  const fallback = adminTs.match(/const SEOUL_STORAGE_BUCKET = '([^']+)';/);
  assert.ok(fallback, 'firebase-admin.ts must declare the SEOUL_STORAGE_BUCKET fallback');
  assert.equal(fallback[1], SEOUL_STORAGE_BUCKET);
  assert.match(
    adminTs,
    /process\.env\.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET \|\| SEOUL_STORAGE_BUCKET/,
    'the environment variable wins, the Seoul bucket is the fallback'
  );
});

test('TC-DF043-04 AC-DF-043.2 admin_web App Hosting config sets the Seoul bucket', () => {
  const yaml = read('admin_web/apphosting.yaml');
  const match = yaml.match(
    /-\s*variable:\s*NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET\s*\n\s*value:\s*["']?([^"'\s]+)["']?/
  );
  assert.ok(match, 'apphosting.yaml must set NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET');
  assert.equal(match[1], SEOUL_STORAGE_BUCKET);
});

test('TC-DF043-04 AC-DF-043.2 no US default bucket string in admin_web/lib or its config files', () => {
  const forbidden = defaultBucketNames(productionProjectId());
  const files = [
    path.join(repoRoot, 'admin_web/.env.example'),
    path.join(repoRoot, 'admin_web/apphosting.yaml'),
    ...walk(path.join(repoRoot, 'admin_web/lib'), (name) => /\.(ts|tsx|js|mjs)$/.test(name)),
  ];
  const offenders = [];
  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    for (const name of forbidden) {
      if (text.includes(name)) offenders.push(`${path.relative(repoRoot, file)}: ${name}`);
    }
  }
  assert.deepEqual(offenders, []);
});

test('TC-DF043-04 AC-DF-043.3 member app constant equals the Functions bucket', () => {
  const dart = read('lib/config/storage_bucket.dart');
  const match = dart.match(/^const String seoulStorageBucket = '([^']+)';$/m);
  assert.ok(match, 'lib/config/storage_bucket.dart must declare seoulStorageBucket');
  assert.equal(match[1], SEOUL_STORAGE_BUCKET);
});

test('TC-DF043-04 AC-DF-043.4 firebase.json pins the Seoul Firestore location and Storage bucket', () => {
  const config = readJson('firebase.json');
  assert.equal(config.firestore.database, '(default)');
  assert.equal(config.firestore.location, 'asia-northeast3');

  assert.ok(Array.isArray(config.storage), 'storage must be the multi-bucket (array) form');
  assert.equal(config.storage.length, 1);
  const [entry] = config.storage;
  assert.equal(entry.bucket, SEOUL_STORAGE_BUCKET);
  assert.equal(entry.rules, 'storage.rules');
  assert.equal(typeof entry.target, 'string');

  // firebase-tools 15.x releases a `target` entry to the buckets .firebaserc maps it to.
  const targets = readJson('.firebaserc').targets;
  const productionId = productionProjectId();
  assert.deepEqual(targets[productionId].storage[entry.target], [SEOUL_STORAGE_BUCKET]);
  for (const [projectId, projectTargets] of Object.entries(targets)) {
    if (projectId === productionId) continue;
    assert.equal(
      projectTargets.storage[entry.target].includes(SEOUL_STORAGE_BUCKET),
      false,
      `${projectId} is an emulator project and must not map the Seoul bucket`
    );
  }
});

test('TC-DF043-04 AC-DF-043.5 every emulator project in CI maps the storage target', () => {
  // The Storage emulator refuses to start when a `target` has no mapping for the --project in use.
  const {storage} = readJson('firebase.json');
  const targets = readJson('.firebaserc').targets;
  const workflowsDir = path.join(repoRoot, '.github/workflows');
  const sources = [
    ...fs.readdirSync(workflowsDir).filter((name) => /\.ya?ml$/.test(name))
      .map((name) => fs.readFileSync(path.join(workflowsDir, name), 'utf8')),
    read('functions/package.json'),
    read('admin_web/package.json'),
  ];
  const projects = new Set();
  for (const text of sources) {
    for (const match of text.matchAll(/emulators:(?:exec|start)[^\n]*?--project[= ]([a-z0-9-]+)/g)) {
      projects.add(match[1]);
    }
  }
  assert.ok(projects.size > 0, 'expected emulator commands in CI');
  for (const projectId of projects) {
    for (const entry of storage) {
      const mapped = targets[projectId]?.storage?.[entry.target];
      assert.ok(
        Array.isArray(mapped) && mapped.length > 0,
        `.firebaserc targets.${projectId}.storage.${entry.target} is missing`
      );
    }
  }
});
