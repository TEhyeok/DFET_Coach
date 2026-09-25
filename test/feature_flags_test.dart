// TC-DF027-02: AppFeatureFlags.fromMap reads appConfig/features fail-closed with the generated keys
// (AC-DF-027.1, AC-DF-027.3, AC-DF-027.6). The Swift twin is TC-DF027-03 (FeatureFlagsTests.swift).
import 'package:dfet_coach/contracts/generated/feature_flags.g.dart';
import 'package:dfet_coach/services/clinical_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _existing = [
  FeatureFlagKey.gut,
  FeatureFlagKey.blood,
  FeatureFlagKey.insights,
];

void main() {
  test(
      'AC-DF-027.1 generated FeatureFlagKey has the eight contract keys, all default false',
      () {
    expect(FeatureFlagKey.values.map((k) => k.wire), [
      'gut',
      'blood',
      'insights',
      'soapV2',
      'bodyComposition',
      'bodyAssessment',
      'memberShare',
      'lidarBeta',
    ]);
    for (final key in FeatureFlagKey.values) {
      expect(key.defaultValue, isFalse, reason: key.wire);
    }
    expect(FeatureFlagKey.fromWire('soapV2'), FeatureFlagKey.soapV2);
    expect(FeatureFlagKey.fromWire('updatedAt'), isNull);
    expect(FeatureFlagKey.fromWire(null), isNull);
  });

  test(
      'AC-DF-027.3 a missing appConfig/features document reads every key false',
      () {
    for (final flags in [
      AppFeatureFlags.fromMap(null),
      AppFeatureFlags.fromMap(<String, dynamic>{}),
    ]) {
      for (final key in FeatureFlagKey.values) {
        expect(flags[key], isFalse, reason: key.wire);
      }
    }
  });

  test('AC-DF-027.3 a missing soapV2 key reads false', () {
    final flags = AppFeatureFlags.fromMap(<String, dynamic>{
      'gut': true,
      'blood': true,
      'insights': true,
      'lidarBeta': true,
    });
    expect(flags.soapV2, isFalse);
    expect(
        flags.gut && flags.blood && flags.insights && flags.lidarBeta, isTrue);
  });

  test(
      'AC-DF-027.3 non-bool values (string "true", 1, null, list, map) read false',
      () {
    const nonBooleans = <Object?>[
      'true',
      'TRUE',
      1,
      1.0,
      null,
      [true],
      {'enabled': true}
    ];
    for (final value in nonBooleans) {
      for (final key in FeatureFlagKey.values) {
        final flags =
            AppFeatureFlags.fromMap(<String, dynamic>{key.wire: value});
        expect(flags[key], isFalse, reason: '${key.wire} = $value');
      }
    }
  });

  test(
      'AC-DF-027.3 bool values are read per key; unknown and audit keys are ignored',
      () {
    for (final key in FeatureFlagKey.values) {
      final on = AppFeatureFlags.fromMap(<String, dynamic>{
        key.wire: true,
        'updatedBy': 'admin',
        'futureFlag': true,
      });
      for (final other in FeatureFlagKey.values) {
        expect(on[other], other == key,
            reason: '${key.wire} on -> ${other.wire}');
      }
      final off = AppFeatureFlags.fromMap(<String, dynamic>{key.wire: false});
      expect(off[key], isFalse, reason: key.wire);
    }
  });

  test('AC-DF-027.6 enabled() turns on only the three existing keys', () {
    const flags = AppFeatureFlags.enabled();
    for (final key in FeatureFlagKey.values) {
      expect(flags[key], _existing.contains(key), reason: key.wire);
    }
    const disabled = AppFeatureFlags.disabled();
    for (final key in FeatureFlagKey.values) {
      expect(disabled[key], isFalse, reason: key.wire);
    }
  });

  test('AC-DF-027.6 existing gut, blood and insights documents read as before',
      () {
    final flags = AppFeatureFlags.fromMap(<String, dynamic>{
      'gut': true,
      'blood': false,
      'insights': true,
    });
    expect(flags.gut, isTrue);
    expect(flags.blood, isFalse);
    expect(flags.insights, isTrue);
    for (final key
        in FeatureFlagKey.values.where((k) => !_existing.contains(k))) {
      expect(flags[key], isFalse, reason: key.wire);
    }
  });
}
