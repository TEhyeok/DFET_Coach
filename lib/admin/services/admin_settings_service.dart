import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSettings {
  final bool notifyNewUser;
  final bool dailyReport;
  final bool errorAlert;
  final bool maskPrivacy;
  final String inactiveCriteria;
  final String autoDeletePolicy;

  AdminSettings({
    this.notifyNewUser = true,
    this.dailyReport = false,
    this.errorAlert = true,
    this.maskPrivacy = true,
    this.inactiveCriteria = '30일',
    this.autoDeletePolicy = '비활성화',
  });

  factory AdminSettings.fromMap(Map<String, dynamic> map) {
    return AdminSettings(
      notifyNewUser: map['notifyNewUser'] ?? true,
      dailyReport: map['dailyReport'] ?? false,
      errorAlert: map['errorAlert'] ?? true,
      maskPrivacy: map['maskPrivacy'] ?? true,
      inactiveCriteria: map['inactiveCriteria'] ?? '30일',
      autoDeletePolicy: map['autoDeletePolicy'] ?? '비활성화',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifyNewUser': notifyNewUser,
      'dailyReport': dailyReport,
      'errorAlert': errorAlert,
      'maskPrivacy': maskPrivacy,
      'inactiveCriteria': inactiveCriteria,
      'autoDeletePolicy': autoDeletePolicy,
    };
  }

  AdminSettings copyWith({
    bool? notifyNewUser,
    bool? dailyReport,
    bool? errorAlert,
    bool? maskPrivacy,
    String? inactiveCriteria,
    String? autoDeletePolicy,
  }) {
    return AdminSettings(
      notifyNewUser: notifyNewUser ?? this.notifyNewUser,
      dailyReport: dailyReport ?? this.dailyReport,
      errorAlert: errorAlert ?? this.errorAlert,
      maskPrivacy: maskPrivacy ?? this.maskPrivacy,
      inactiveCriteria: inactiveCriteria ?? this.inactiveCriteria,
      autoDeletePolicy: autoDeletePolicy ?? this.autoDeletePolicy,
    );
  }
}

final adminSettingsProvider =
    StateNotifierProvider<AdminSettingsService, AsyncValue<AdminSettings>>(
        (ref) {
  return AdminSettingsService();
});

class AdminSettingsService extends StateNotifier<AsyncValue<AdminSettings>> {
  AdminSettingsService() : super(const AsyncValue.loading()) {
    _init();
  }

  final _docRef = FirebaseFirestore.instance
      .collection('system_settings')
      .doc('admin_config');

  Future<void> _init() async {
    try {
      final doc = await _docRef.get();
      if (doc.exists) {
        state = AsyncValue.data(AdminSettings.fromMap(doc.data()!));
      } else {
        // Initialize with defaults if not exists
        final defaultSettings = AdminSettings();
        await _docRef.set(defaultSettings.toMap());
        state = AsyncValue.data(defaultSettings);
      }

      // Listen for real-time updates
      _docRef.snapshots().listen((snapshot) {
        if (snapshot.exists) {
          state = AsyncValue.data(AdminSettings.fromMap(snapshot.data()!));
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    try {
      await _docRef.update({key: value});
    } catch (e) {
      // If document doesn't exist (e.g. deleted manually), recreate it
      if (e is FirebaseException && e.code == 'not-found') {
        final defaultSettings = AdminSettings();
        await _docRef.set(defaultSettings.toMap());
        await _docRef.update({key: value});
      } else {
        rethrow;
      }
    }
  }
}
