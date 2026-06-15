import 'package:flutter/foundation.dart';

class TradeModeProvider extends ChangeNotifier {
  bool _isDemoMode = true;

  bool get isDemoMode => _isDemoMode;
  bool get isRealMode => !_isDemoMode;

  void setDemoMode(bool value) {
    if (_isDemoMode == value) return;
    _isDemoMode = value;
    notifyListeners();
  }
}
