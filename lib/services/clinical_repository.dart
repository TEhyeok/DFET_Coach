import 'package:cloud_firestore/cloud_firestore.dart';
import '../contracts/generated/feature_flags.g.dart';
import '../models/clinical_reports.dart';

/// `appConfig/features` (ADR-010, V1-05 §4.17). Keys come from the generated [FeatureFlagKey]
/// (contracts/feature-flags.v1.json, DF-027).
///
/// Fail-closed (AC-IA-02, AC-DF-027.3): a missing document, a missing key or a value that is not
/// a bool (for example the string 'true') reads as the key's contract default, which is false.
class AppFeatureFlags {
  final bool gut;
  final bool blood;
  final bool insights;
  final bool soapV2;
  final bool bodyComposition;
  final bool bodyAssessment;
  final bool memberShare;
  final bool lidarBeta;

  const AppFeatureFlags({
    required this.gut,
    required this.blood,
    required this.insights,
    this.soapV2 = false,
    this.bodyComposition = false,
    this.bodyAssessment = false,
    this.memberShare = false,
    this.lidarBeta = false,
  });

  /// The three existing member-app features only (D4, AC-DF-027.6). The v1 flags stay false.
  const AppFeatureFlags.enabled()
      : gut = true,
        blood = true,
        insights = true,
        soapV2 = false,
        bodyComposition = false,
        bodyAssessment = false,
        memberShare = false,
        lidarBeta = false;

  const AppFeatureFlags.disabled()
      : gut = false,
        blood = false,
        insights = false,
        soapV2 = false,
        bodyComposition = false,
        bodyAssessment = false,
        memberShare = false,
        lidarBeta = false;

  factory AppFeatureFlags.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppFeatureFlags.disabled();
    bool read(FeatureFlagKey key) {
      final value = map[key.wire];
      return value is bool ? value : key.defaultValue;
    }

    return AppFeatureFlags(
      gut: read(FeatureFlagKey.gut),
      blood: read(FeatureFlagKey.blood),
      insights: read(FeatureFlagKey.insights),
      soapV2: read(FeatureFlagKey.soapV2),
      bodyComposition: read(FeatureFlagKey.bodyComposition),
      bodyAssessment: read(FeatureFlagKey.bodyAssessment),
      memberShare: read(FeatureFlagKey.memberShare),
      lidarBeta: read(FeatureFlagKey.lidarBeta),
    );
  }

  /// Value of [key]. Every generated key maps to one field.
  bool operator [](FeatureFlagKey key) => switch (key) {
        FeatureFlagKey.gut => gut,
        FeatureFlagKey.blood => blood,
        FeatureFlagKey.insights => insights,
        FeatureFlagKey.soapV2 => soapV2,
        FeatureFlagKey.bodyComposition => bodyComposition,
        FeatureFlagKey.bodyAssessment => bodyAssessment,
        FeatureFlagKey.memberShare => memberShare,
        FeatureFlagKey.lidarBeta => lidarBeta,
      };
}

class ClinicalRepository {
  ClinicalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AppFeatureFlags> watchFeatureFlags() {
    return _firestore.collection('appConfig').doc('features').snapshots().map(
          (snapshot) => AppFeatureFlags.fromMap(snapshot.data()),
        );
  }

  Stream<List<GutReport>> watchGutReports(String userId) {
    return _firestore
        .collection('gutReports')
        .where('userId', isEqualTo: userId)
        .orderBy('sampledAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GutReport.fromMap(doc.data(), doc.id))
            .toList(growable: false));
  }

  Stream<GutReport?> watchGutReport(String reportId) {
    return _firestore.collection('gutReports').doc(reportId).snapshots().map(
          (snapshot) => snapshot.exists
              ? GutReport.fromMap(snapshot.data()!, snapshot.id)
              : null,
        );
  }

  Stream<GutExpertReport?> watchGutExpertReport(String reportId) {
    return _firestore
        .collection('gutReportExperts')
        .doc(reportId)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? GutExpertReport.fromMap(snapshot.data()!, snapshot.id)
            : null);
  }

  Stream<List<BloodReport>> watchBloodReports(String userId) {
    return _firestore
        .collection('bloodReports')
        .where('userId', isEqualTo: userId)
        .orderBy('sampledAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BloodReport.fromMap(doc.data(), doc.id))
            .toList(growable: false));
  }

  Stream<BloodReport?> watchBloodReport(String reportId) {
    return _firestore.collection('bloodReports').doc(reportId).snapshots().map(
          (snapshot) => snapshot.exists
              ? BloodReport.fromMap(snapshot.data()!, snapshot.id)
              : null,
        );
  }

  Stream<BloodExpertReport?> watchBloodExpertReport(String reportId) {
    return _firestore
        .collection('bloodReportExperts')
        .doc(reportId)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? BloodExpertReport.fromMap(snapshot.data()!, snapshot.id)
            : null);
  }

  Stream<List<HealthSnapshot>> watchHealthSnapshots(String userId) {
    return _firestore
        .collection('healthSnapshots')
        .where('userId', isEqualTo: userId)
        .orderBy('asOf', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HealthSnapshot.fromMap(doc.data(), doc.id))
            .toList(growable: false));
  }

  Stream<HealthSnapshot?> watchHealthSnapshot(String snapshotId) {
    return _firestore
        .collection('healthSnapshots')
        .doc(snapshotId)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? HealthSnapshot.fromMap(snapshot.data()!, snapshot.id)
            : null);
  }
}
