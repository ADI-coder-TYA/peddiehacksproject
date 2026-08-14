import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AccessibilityProvider extends ChangeNotifier {
  static const String _keyHighContrast = 'pref_high_contrast';
  static const String _keyLanguage = 'pref_selected_language';
  static const String _keyContactChannel = 'pref_contact_channel';
  static const String _keyEmergencyAlerts = 'pref_emergency_alerts';

  bool _highContrastMode = false;
  String _selectedLanguage = 'English';
  String _preferredContactChannel = 'Email';
  bool _realTimeEmergencyAlerts = true;

  bool get highContrastMode => _highContrastMode;
  String get selectedLanguage => _selectedLanguage;
  String get preferredContactChannel => _preferredContactChannel;
  bool get realTimeEmergencyAlerts => _realTimeEmergencyAlerts;

  /// Returns BCP-47 language code for speech-to-text / LLM context
  String get languageCode {
    switch (_selectedLanguage) {
      case 'Español':
        return 'es-ES';
      case 'Français':
        return 'fr-FR';
      case 'Hindi':
        return 'hi-IN';
      case 'Mandarin':
        return 'zh-CN';
      case 'English':
      default:
        return 'en-US';
    }
  }

  AccessibilityProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _highContrastMode = prefs.getBool(_keyHighContrast) ?? false;
      _selectedLanguage = prefs.getString(_keyLanguage) ?? 'English';
      _preferredContactChannel = prefs.getString(_keyContactChannel) ?? 'Email';
      _realTimeEmergencyAlerts = prefs.getBool(_keyEmergencyAlerts) ?? true;
      
      ApiConfig.preferredContactChannel = _preferredContactChannel;
      ApiConfig.selectedLanguage = _selectedLanguage;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading accessibility preferences: $e');
    }
  }

  Future<void> setHighContrastMode(bool enabled) async {
    _highContrastMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHighContrast, enabled);
    } catch (e) {
      debugPrint('Error saving high contrast pref: $e');
    }
  }

  Future<void> setSelectedLanguage(String language) async {
    _selectedLanguage = language;
    ApiConfig.selectedLanguage = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, language);
    } catch (e) {
      debugPrint('Error saving language pref: $e');
    }
  }

  Future<void> setPreferredContactChannel(String channel) async {
    _preferredContactChannel = channel;
    ApiConfig.preferredContactChannel = channel;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyContactChannel, channel);
    } catch (e) {
      debugPrint('Error saving contact channel pref: $e');
    }
  }

  Future<void> setRealTimeEmergencyAlerts(bool enabled) async {
    _realTimeEmergencyAlerts = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEmergencyAlerts, enabled);
    } catch (e) {
      debugPrint('Error saving emergency alerts pref: $e');
    }
  }
}
