import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PreferencesProvider extends ChangeNotifier {
  static const String _keyHighContrast = 'pref_high_contrast';
  static const String _keyRealTimeAlerts = 'pref_real_time_alerts';
  static const String _keyPreferredChannel = 'pref_preferred_channel';
  static const String _keySelectedLanguage = 'pref_selected_language';

  bool _isHighContrast = false;
  bool _realTimeAlerts = true;
  String _preferredChannel = 'SMS'; // 'EMAIL' | 'SMS' | 'WHATSAPP'
  String _selectedLanguage = 'en';  // 'en' | 'es' | 'hi' | 'zh'

  bool get isHighContrast => _isHighContrast;
  bool get realTimeAlerts => _realTimeAlerts;
  String get preferredChannel => _preferredChannel;
  String get selectedLanguage => _selectedLanguage;

  /// Returns BCP-47 language tag for Whisper / Speech Recognition
  String get speechLanguageCode {
    switch (_selectedLanguage) {
      case 'es':
        return 'es-ES';
      case 'hi':
        return 'hi-IN';
      case 'zh':
        return 'zh-CN';
      case 'en':
      default:
        return 'en-US';
    }
  }

  /// Returns display label for language
  String get languageDisplayName {
    switch (_selectedLanguage) {
      case 'es':
        return 'Español';
      case 'hi':
        return 'Hindi (हिन्दी)';
      case 'zh':
        return 'Mandarin (中文)';
      case 'en':
      default:
        return 'English';
    }
  }

  PreferencesProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isHighContrast = prefs.getBool(_keyHighContrast) ?? false;
      _realTimeAlerts = prefs.getBool(_keyRealTimeAlerts) ?? true;
      _preferredChannel = prefs.getString(_keyPreferredChannel) ?? 'SMS';
      _selectedLanguage = prefs.getString(_keySelectedLanguage) ?? 'en';
      
      ApiConfig.preferredContactChannel = _preferredChannel;
      ApiConfig.selectedLanguage = languageDisplayName;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> toggleHighContrast(bool value) async {
    _isHighContrast = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHighContrast, value);
    } catch (e) {
      debugPrint('Error saving high contrast pref: $e');
    }
  }

  Future<void> setContactChannel(String channel) async {
    _preferredChannel = channel;
    ApiConfig.preferredContactChannel = channel;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPreferredChannel, channel);
      await _syncPreferencesToBackend();
    } catch (e) {
      debugPrint('Error saving contact channel pref: $e');
    }
  }

  Future<void> toggleEmergencyAlerts(bool value) async {
    _realTimeAlerts = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRealTimeAlerts, value);
      await _syncPreferencesToBackend();
    } catch (e) {
      debugPrint('Error saving emergency alerts pref: $e');
    }
  }

  Future<void> setLanguage(String langCode) async {
    _selectedLanguage = langCode;
    ApiConfig.selectedLanguage = languageDisplayName;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedLanguage, langCode);
    } catch (e) {
      debugPrint('Error saving language pref: $e');
    }
  }

  /// Syncs preferences to student profile record on backend
  Future<void> _syncPreferencesToBackend() async {
    final userId = ApiConfig.userId;
    if (userId == null || userId.isEmpty) return;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/students/preferences');
      await http.post(
        url,
        headers: ApiConfig.studentHeaders,
        body: jsonEncode({
          'studentId': userId,
          'preferredChannel': _preferredChannel,
          'alertsEnabled': _realTimeAlerts,
          'language': _selectedLanguage,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Optional preference sync note: $e');
    }
  }
}
