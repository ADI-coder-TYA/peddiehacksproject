import 'package:flutter/material.dart';

class AccessibilityProvider extends ChangeNotifier {
  bool _highContrast = false;
  double _textScale = 1.0;
  bool _reduceMotion = false;
  String _selectedLanguage = 'English';
  String _preferredContactChannel = 'Email';
  bool _realTimeEmergencyAlerts = true;

  bool get highContrast => _highContrast;
  bool get highContrastMode => _highContrast;
  double get textScale => _textScale;
  bool get reduceMotion => _reduceMotion;
  String get selectedLanguage => _selectedLanguage;
  String get preferredContactChannel => _preferredContactChannel;
  bool get realTimeEmergencyAlerts => _realTimeEmergencyAlerts;

  void toggleHighContrast() {
    _highContrast = !_highContrast;
    notifyListeners();
  }

  void setHighContrastMode(bool val) {
    _highContrast = val;
    notifyListeners();
  }

  void setSelectedLanguage(String lang) {
    _selectedLanguage = lang;
    notifyListeners();
  }

  void setPreferredContactChannel(String channel) {
    _preferredContactChannel = channel;
    notifyListeners();
  }

  void setRealTimeEmergencyAlerts(bool val) {
    _realTimeEmergencyAlerts = val;
    notifyListeners();
  }

  void setTextScale(double scale) {
    _textScale = scale.clamp(0.8, 2.0);
    notifyListeners();
  }

  void toggleReduceMotion() {
    _reduceMotion = !_reduceMotion;
    notifyListeners();
  }

  ThemeData apply(ThemeData base) {
    if (_highContrast) {
      return base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
      );
    }
    return base;
  }
}
