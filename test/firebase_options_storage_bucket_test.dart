// DF-043 (DEC-19, Q-08): the member app names the Seoul Storage bucket explicitly.
// TC-DF043-02. Bucket and project values come from the app code; this file writes none of them.
import 'package:dfet_coach/config/storage_bucket.dart';
import 'package:dfet_coach/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const platforms = <String, FirebaseOptions>{
    'android': DefaultFirebaseOptions.android,
    'ios': DefaultFirebaseOptions.ios,
    'web': DefaultFirebaseOptions.web,
  };

  test(
      'TC-DF043-02 AC-DF-043.3 every platform storageBucket is the Seoul bucket constant',
      () {
    for (final entry in platforms.entries) {
      expect(
        entry.value.storageBucket,
        seoulStorageBucket,
        reason: '${entry.key} storageBucket must be seoulStorageBucket '
            '(re-apply DF-043 after flutterfire configure)',
      );
    }
  });

  test(
      'TC-DF043-02 AC-DF-043.3 the Seoul bucket constant is not the default bucket',
      () {
    for (final entry in platforms.entries) {
      final projectId = entry.value.projectId;
      expect(
        seoulStorageBucket,
        isNot(
            anyOf('$projectId.firebasestorage.app', '$projectId.appspot.com')),
        reason:
            '${entry.key}: the default bucket cannot move to Seoul (DEC-19)',
      );
    }
  });

  test(
      'TC-DF043-02 AC-DF-043.3 the Seoul bucket constant is a plain GCS bucket name',
      () {
    expect(seoulStorageBucket,
        matches(RegExp(r'^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$')));
    expect(seoulStorageBucket, isNot(startsWith('gs://')));
  });
}
