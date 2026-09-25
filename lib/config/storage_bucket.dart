import 'package:firebase_storage/firebase_storage.dart';

/// Seoul (asia-northeast3) Cloud Storage bucket for the member app (DEC-19, DF-043).
///
/// The project's default bucket cannot leave its US location, so the Seoul bucket is an additional
/// bucket (owner action DF-942) and the app names it explicitly through [appStorage].
///
/// `DefaultFirebaseOptions.*.storageBucket` deliberately stays equal to the native config files
/// (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`). On Android and iOS the
/// native SDK creates the default app from those files before Dart runs, and
/// `Firebase.initializeApp(options:)` throws `[core/duplicate-app]` when the Dart `storageBucket`
/// differs from the native one. `test/firebase_options_storage_bucket_test.dart` keeps them equal.
///
/// The name is not a secret. The same value lives in `functions/src/shared/storage.js`,
/// `admin_web/.env.example`, `admin_web/apphosting.yaml`, the `admin_web/lib/firebase-admin.ts`
/// fallback and the `seoul` storage target in `.firebaserc`;
/// `functions/test/unit/storage-bucket.test.js` keeps them equal.
const String seoulStorageBucket = 'dfetmanage-seoul';

/// `gs://` URL of [seoulStorageBucket], the form [FirebaseStorage.instanceFor] expects.
const String seoulStorageBucketUrl = 'gs://$seoulStorageBucket';

/// The Storage instance every member-app upload and download goes through.
///
/// Use this instead of `FirebaseStorage.instance`, which targets the default (US) bucket.
/// `test/firebase_options_storage_bucket_test.dart` fails if `FirebaseStorage.instance` appears in
/// `lib/` outside this file.
FirebaseStorage appStorage() =>
    FirebaseStorage.instanceFor(bucket: seoulStorageBucketUrl);
