'use strict';

// Storage bucket selection for every Functions Storage access (DF-043, DEC-19, G-09).
//
// - Production writes to the Seoul (asia-northeast3) bucket. The project's default bucket cannot move
//   out of its US location, so the Seoul bucket is an additional bucket (owner action DF-942) and code
//   must name it explicitly.
// - Under the emulator (FUNCTIONS_EMULATOR=true or FIREBASE_STORAGE_EMULATOR_HOST set) the default
//   bucket is kept, so emulator tests keep reading and writing `<projectId>.appspot.com` as before.
// - This is the only place in functions/index.js and functions/src/** that may call
//   `storage().bucket(...)` at all (test/unit/storage-bucket.test.js, TC-DF043-04).
// - Account deletion also clears the legacy default bucket: member uploads before DF-043, and installed
//   app versions that predate it, wrote `requests/{uid}/` and `posts/*_{uid}.jpg` there (G-09).
//
// The bucket name is not a secret. The same value lives in lib/config/storage_bucket.dart (member app),
// admin_web/.env.example, admin_web/apphosting.yaml and the admin_web/lib/firebase-admin.ts fallback, and the `seoul` storage
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

// Buckets account deletion must clear: the app bucket first, then the legacy default bucket when it
// is a different bucket. Under the emulator both are the default bucket, so the list has one entry.
function accountDeletionBuckets(admin, env = process.env) {
  const primary = appBucket(admin, env);
  if (appBucketName(env) === undefined) return [primary];
  const legacy = admin.storage().bucket();
  return legacy.name === primary.name ? [primary] : [primary, legacy];
}

function logDeletionFailure(message, bucket, error) {
  console.warn(message, {bucket: bucket && bucket.name}, error);
}

// Deletes a member's request media (`requests/{uid}/`) and community images (`posts/*_{uid}.jpg`)
// from every account deletion bucket. A failure in one bucket (missing, misconfigured, transient) is
// logged and does not stop the other buckets or the caller's cascade (auth user deletion follows).
async function deleteAccountMedia(admin, uid, env = process.env) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new TypeError('deleteAccountMedia: uid is required');
  }
  let buckets;
  try {
    buckets = accountDeletionBuckets(admin, env);
  } catch (error) {
    logDeletionFailure('Failed to resolve Storage buckets during account deletion', null, error);
    return;
  }
  const suffix = `_${uid}.jpg`;
  await Promise.all(buckets.map(async (bucket) => {
    try {
      await bucket.deleteFiles({prefix: `requests/${uid}/`});
    } catch (error) {
      logDeletionFailure('Failed to delete request media during account deletion', bucket, error);
    }
    try {
      const [postFiles] = await bucket.getFiles({prefix: 'posts/'});
      await Promise.all(
        postFiles
          .filter((file) => file.name.endsWith(suffix))
          .map((file) => file.delete().catch((error) => {
            logDeletionFailure('Failed to delete community media during account deletion', bucket, error);
          }))
      );
    } catch (error) {
      logDeletionFailure('Failed to list community media during account deletion', bucket, error);
    }
  }));
}

module.exports = {
  SEOUL_STORAGE_BUCKET,
  accountDeletionBuckets,
  appBucket,
  appBucketName,
  deleteAccountMedia,
  isStorageEmulator,
};
