'use strict';

// Storage bucket selection for every Functions Storage access (DF-043, DEC-19, G-09).
//
// - Production writes to the Seoul (asia-northeast3) bucket. The project's default bucket cannot move
//   out of its US location, so the Seoul bucket is an additional bucket (owner action DF-942) and code
//   must name it explicitly.
// - Under the emulator (FUNCTIONS_EMULATOR=true or FIREBASE_STORAGE_EMULATOR_HOST set) the default
//   bucket is kept, so emulator tests keep reading and writing `<projectId>.appspot.com` as before.
// - This is the only place in functions/index.js and functions/src/** that may call
//   `storage().bucket()` without a name (test/unit/storage-bucket.test.js, TC-DF043-04).
//
// The bucket name is not a secret. The same value lives in lib/config/storage_bucket.dart (member app),
// admin_web/.env.example and the admin_web/lib/firebase-admin.ts fallback, and the `seoul` storage
// target in .firebaserc; test/unit/storage-bucket.test.js keeps them equal. The trainer app pins the
// same bucket in DF-104 (`StorageBucket.seoul`).

const SEOUL_STORAGE_BUCKET = 'dfetmanage-seoul';

function isStorageEmulator(env = process.env) {
  return env.FUNCTIONS_EMULATOR === 'true' || Boolean(env.FIREBASE_STORAGE_EMULATOR_HOST);
}

// Bucket name to pass to `storage().bucket(name)`, or undefined for the app's default bucket.
function appBucketName(env = process.env) {
  return isStorageEmulator(env) ? undefined : SEOUL_STORAGE_BUCKET;
}

// The bucket every Functions Storage access goes through.
// `admin` is the firebase-admin namespace (index.js) or the injected one (src/clinical/ingestion.js).
function appBucket(admin, env = process.env) {
  if (!admin || typeof admin.storage !== 'function') {
    throw new TypeError('appBucket: firebase-admin namespace with storage() is required');
  }
  const name = appBucketName(env);
  const storage = admin.storage();
  return name === undefined ? storage.bucket() : storage.bucket(name);
}

module.exports = {
  SEOUL_STORAGE_BUCKET,
  appBucket,
  appBucketName,
  isStorageEmulator,
};
