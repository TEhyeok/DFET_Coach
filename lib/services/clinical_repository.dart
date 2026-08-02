import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clinical_reports.dart';

class AppFeatureFlags {
  final bool gut;
  final bool blood;
  final bool insights;

  const AppFeatureFlags({
    required this.gut,
    required this.blood,
    required this.insights,
  });

  const AppFeatureFlags.enabled()
      : gut = true,
        blood = true,
        insights = true;

  const AppFeatureFlags.disabled()
      : gut = false,
        blood = false,
        insights = false;

  factory AppFeatureFlags.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppFeatureFlags.disabled();
    return AppFeatureFlags(
      gut: map['gut'] as bool? ?? false,
      blood: map['blood'] as bool? ?? false,
      insights: map['insights'] as bool? ?? false,
    );
  }
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
