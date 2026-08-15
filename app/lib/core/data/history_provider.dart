import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class HistoryNotifier extends StateNotifier<List<TransferRecord>> {
  HistoryNotifier() : super(const []) {
    _load();
  }

  static const _storageKey = 'transfer_history';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).map((e) => TransferRecord.fromJson(e as Map<String, dynamic>)).toList();
      state = list;
    }
  }

  Future<void> add(TransferRecord record) async {
    state = [record, ...state];
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<TransferRecord>>((ref) {
  return HistoryNotifier();
});
