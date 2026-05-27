import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return dateOnly(DateTime.now());
});

final selectedDateStringProvider = Provider<String>((ref) {
  return dateKey(ref.watch(selectedDateProvider));
});

final isSelectedDateTodayProvider = Provider<bool>((ref) {
  return dateOnly(ref.watch(selectedDateProvider)) == dateOnly(DateTime.now());
});
