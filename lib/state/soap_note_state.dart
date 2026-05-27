import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_logger.dart';
import '../models/soap_note.dart';
import 'app_state.dart';

const _guestTrainerSoapNotesKey = 'dfet.guestTrainer.soapNotes.v1';

final guestTrainerSoapNotesProvider =
    StateNotifierProvider<GuestTrainerSoapNotesNotifier, List<SoapNote>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GuestTrainerSoapNotesNotifier(prefs);
});

final soapNotesProvider =
    FutureProvider.autoDispose<List<SoapNote>>((ref) async {
  final isTrainerGuest = ref.watch(isTrainerGuestModeProvider);
  if (isTrainerGuest) {
    final notes = ref.watch(guestTrainerSoapNotesProvider);
    return [...notes]..sort((a, b) => b.date.compareTo(a.date));
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final firestoreService = ref.watch(firestoreServiceProvider);
  final profile = await ref.watch(userProfileProvider.future);

  if (profile?.isTrainer == true || profile?.isAdmin == true) {
    return firestoreService.loadTrainerSoapNotes(user.uid);
  }

  return firestoreService.loadMemberSoapNotes(
    memberId: user.uid,
    memberEmail: user.email,
  );
});

class GuestTrainerSoapNotesNotifier extends StateNotifier<List<SoapNote>> {
  GuestTrainerSoapNotesNotifier(this._prefs) : super(const []) {
    _load();
  }

  final SharedPreferences _prefs;

  Future<void> upsert(SoapNote note) async {
    state = [
      note,
      ...state.where((item) => item.id != note.id),
    ]..sort(_sortByLatestDate);
    await _persist();
  }

  Future<void> delete(String id) async {
    state = state.where((item) => item.id != id).toList()
      ..sort(_sortByLatestDate);
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _prefs.remove(_guestTrainerSoapNotesKey);
  }

  void _load() {
    final raw = _prefs.getString(_guestTrainerSoapNotesKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final notes = <SoapNote>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final id = data.remove('id') as String?;
        if (id == null || id.isEmpty) continue;
        notes.add(SoapNote.fromFirestore(data, id));
      }

      state = notes..sort(_sortByLatestDate);
    } catch (error, stackTrace) {
      AppLogger.warning(
        '[GuestTrainerSoapNotes] 로컬 SOAP 노트 로드 실패',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _persist() async {
    final encoded = state.map((note) {
      final data = note.toFirestore();
      data['id'] = note.id;
      return data;
    }).toList();
    await _prefs.setString(_guestTrainerSoapNotesKey, jsonEncode(encoded));
  }
}

int _sortByLatestDate(SoapNote a, SoapNote b) => b.date.compareTo(a.date);
