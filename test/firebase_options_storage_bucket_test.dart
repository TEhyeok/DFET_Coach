// DF-043 (DEC-19, Q-08): the member app names the Seoul Storage bucket explicitly through
// appStorage(), and DefaultFirebaseOptions stays equal to the native Firebase config files.
// TC-DF043-02. Bucket and project values come from the app code and config; this file writes none.
import 'dart:convert';
import 'dart:io';

import 'package:dfet_coach/config/storage_bucket.dart';
import 'package:dfet_coach/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter_test/flutter_test.dart';

String _androidNativeBucket() {
  final json =
      jsonDecode(File('android/app/google-services.json').readAsStringSync())
          as Map<String, dynamic>;
  return (json['project_info'] as Map<String, dynamic>)['storage_bucket']
      as String;
}

String _iosNativeBucket() {
  final plist = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
  final match = RegExp(r'<key>STORAGE_BUCKET</key>\s*<string>([^<]+)</string>')
      .firstMatch(plist);
  expect(match, isNotNull,
      reason: 'GoogleService-Info.plist must set STORAGE_BUCKET');
  return match!.group(1)!;
}

void main() {
  const platforms = <String, FirebaseOptions>{
    'android': DefaultFirebaseOptions.android,
    'ios': DefaultFirebaseOptions.ios,
    'web': DefaultFirebaseOptions.web,
  };

  test(
      'TC-DF043-02 AC-DF-043.3 native platform storageBucket equals the native config file '
      '(no [core/duplicate-app])', () {
    // The native SDK creates the default app from these files before Dart runs. A different Dart
    // storageBucket makes Firebase.initializeApp throw [core/duplicate-app] and skips App Check.
    expect(DefaultFirebaseOptions.android.storageBucket, _androidNativeBucket(),
        reason:
            'firebase_options.dart android must match google-services.json storage_bucket');
    expect(DefaultFirebaseOptions.ios.storageBucket, _iosNativeBucket(),
        reason:
            'firebase_options.dart ios must match GoogleService-Info.plist STORAGE_BUCKET');
  });

  test(
      'TC-DF043-02 AC-DF-043.3 the Seoul bucket constant is not the default bucket',
      () {
    for (final entry in platforms.entries) {
      final projectId = entry.value.projectId;
      expect(
        seoulStorageBucket,
        isNot(anyOf('$projectId.firebasestorage.app', '$projectId.appspot.com',
            entry.value.storageBucket)),
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
    expect(seoulStorageBucketUrl, 'gs://$seoulStorageBucket');
  });

  test(
      'TC-DF043-02 AC-DF-043.3 lib/ uses appStorage(), never FirebaseStorage.instance, '
      'outside lib/config/storage_bucket.dart', () {
    final helper = File('lib/config/storage_bucket.dart').absolute.path;
    final offenders = <String>[];
    final pattern =
        RegExp(r'FirebaseStorage\s*\.\s*(instance\b|instanceFor\s*\()');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.absolute.path == helper) continue;
      final text = entity.readAsStringSync();
      for (final match in pattern.allMatches(text)) {
        final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
        offenders.add('${entity.path}:$line');
      }
    }
    expect(offenders, isEmpty,
        reason:
            'use appStorage() from lib/config/storage_bucket.dart (Seoul bucket, DF-043)');

    final helperText = File(helper).readAsStringSync();
    expect(helperText,
        contains('FirebaseStorage.instanceFor(bucket: seoulStorageBucketUrl)'));
  });
}
