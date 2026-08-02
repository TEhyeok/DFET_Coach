import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/clinical_reports.dart';
import '../services/clinical_repository.dart';
import 'auth_state.dart';

final clinicalRepositoryProvider = Provider<ClinicalRepository>((ref) {
  return ClinicalRepository();
});

final featureFlagsProvider = StreamProvider<AppFeatureFlags>((ref) {
  return ref.watch(clinicalRepositoryProvider).watchFeatureFlags();
});

final gutReportsProvider = StreamProvider<List<GutReport>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(clinicalRepositoryProvider).watchGutReports(user.uid);
});

final latestGutReportProvider = Provider<AsyncValue<GutReport?>>((ref) {
  return ref.watch(gutReportsProvider).whenData(
        (reports) => reports.isEmpty ? null : reports.first,
      );
});

final gutReportProvider = StreamProvider.family<GutReport?, String>((ref, id) {
  return ref.watch(clinicalRepositoryProvider).watchGutReport(id);
});

final gutExpertReportProvider =
    StreamProvider.family<GutExpertReport?, String>((ref, id) {
  return ref.watch(clinicalRepositoryProvider).watchGutExpertReport(id);
});

final bloodReportsProvider = StreamProvider<List<BloodReport>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(clinicalRepositoryProvider).watchBloodReports(user.uid);
});

final latestBloodReportProvider = Provider<AsyncValue<BloodReport?>>((ref) {
  return ref.watch(bloodReportsProvider).whenData(
        (reports) => reports.isEmpty ? null : reports.first,
      );
});

final bloodReportProvider =
    StreamProvider.family<BloodReport?, String>((ref, id) {
  return ref.watch(clinicalRepositoryProvider).watchBloodReport(id);
});

final bloodExpertReportProvider =
    StreamProvider.family<BloodExpertReport?, String>((ref, id) {
  return ref.watch(clinicalRepositoryProvider).watchBloodExpertReport(id);
});

final healthSnapshotsProvider = StreamProvider<List<HealthSnapshot>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(clinicalRepositoryProvider).watchHealthSnapshots(user.uid);
});

final latestHealthSnapshotProvider =
    Provider<AsyncValue<HealthSnapshot?>>((ref) {
  return ref.watch(healthSnapshotsProvider).whenData(
        (snapshots) => snapshots.isEmpty ? null : snapshots.first,
      );
});

final healthSnapshotProvider =
    StreamProvider.family<HealthSnapshot?, String>((ref, id) {
  return ref.watch(clinicalRepositoryProvider).watchHealthSnapshot(id);
});
