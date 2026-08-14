import 'package:flutter/material.dart';

class AccessibilityProvider extends ChangeNotifier {
  bool _highContrast = false;
  double _textScale = 1.0;
  bool _reduceMotion = false;

  bool get highContrast => _highContrast;
  double get textScale => _textScale;
  bool get reduceMotion => _reduceMotion;

  void toggleHighContrast() {
    _highContrast = !_highContrast;
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
