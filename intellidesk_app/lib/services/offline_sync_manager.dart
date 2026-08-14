import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncManager extends ChangeNotifier {
  static const String _storageKey = 'medaccess_offline_pending_claims';
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<void> init() async {
    // Initialized from SharedPreferences on demand
  }

  Future<void> queueClaim(String id, String payload) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_storageKey) ?? [];
    list.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded['id'] == id;
      } catch (_) {
        return false;
      }
    });
    list.add(jsonEncode({
      'id': id,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }));
    await prefs.setStringList(_storageKey, list);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getPendingClaims() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_storageKey) ?? [];
    return list.map((item) {
      try {
        return jsonDecode(item) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).toList();
  }

  Future<void> removeClaim(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_storageKey) ?? [];
    list.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_storageKey, list);
    notifyListeners();
  }
}
