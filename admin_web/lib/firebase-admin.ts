import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

// Seoul (asia-northeast3) Storage bucket, DEC-19 / DF-043. Used when the environment does not set
// NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET. Same value as functions/src/shared/storage.js
// (functions/test/unit/storage-bucket.test.js keeps them equal). Not a secret.
const SEOUL_STORAGE_BUCKET = 'dfetmanage-seoul';

function storageBucket(): string {
  return process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || SEOUL_STORAGE_BUCKET;
}

function getAdminApp(): App {
  const existing = getApps()[0];
  if (existing) return existing;

  const encoded = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (encoded) {
    const serviceAccount = JSON.parse(
      Buffer.from(encoded, 'base64').toString('utf8'),
    );
    return initializeApp({
      credential: cert(serviceAccount),
      storageBucket: storageBucket(),
    });
  }

  return initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID ?? 'dfetmanage',
    storageBucket: storageBucket(),
  });
}

export const adminApp = getAdminApp();
export const adminAuth = getAuth(adminApp);
export const adminDb = getFirestore(adminApp);
export const adminStorage = getStorage(adminApp);
