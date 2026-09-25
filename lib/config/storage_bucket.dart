/// Seoul (asia-northeast3) Cloud Storage bucket for the member app (DEC-19, DF-043).
///
/// The project's default bucket cannot leave its US location, so the Seoul bucket is an additional
/// bucket (owner action DF-942) and the app names it explicitly through
/// `DefaultFirebaseOptions.*.storageBucket`. `FirebaseStorage.instance` then uses this bucket.
///
/// The name is not a secret. The same value lives in `functions/src/shared/storage.js`,
/// `admin_web/.env.example`, the `admin_web/lib/firebase-admin.ts` fallback and the `seoul` storage
/// target in `.firebaserc`; `functions/test/unit/storage-bucket.test.js` keeps them equal and
/// `test/firebase_options_storage_bucket_test.dart` fails if a FlutterFire regeneration brings the
/// default bucket back.
const String seoulStorageBucket = 'dfetmanage-seoul';
