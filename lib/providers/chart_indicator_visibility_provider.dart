import 'package:flutter/foundation.dart';

class ChartIndicatorVisibilityProvider extends ChangeNotifier {
  static const minChartScale = 0.7;
  static const maxChartScale = 4.0;

  bool _showEma3 = true;
  bool _showEma7 = true;
  bool _showEma9 = true;
  bool _showEma21 = true;
  bool _showBoll = true;
  bool _showSar = true;
  bool _showRsi = true;
  double _chartScale = 1.35;

  bool get showEma3 => _showEma3;
  bool get showEma7 => _showEma7;
  bool get showEma9 => _showEma9;
  bool get showEma21 => _showEma21;
  bool get showBoll => _showBoll;
  bool get showSar => _showSar;
  bool get showRsi => _showRsi;
  double get chartScale => _chartScale;

  void toggleEma3() {
    _showEma3 = !_showEma3;
    notifyListeners();
  }

  void toggleEma7() {
    _showEma7 = !_showEma7;
    notifyListeners();
  }

  void toggleEma9() {
    _showEma9 = !_showEma9;
    notifyListeners();
  }

  void toggleEma21() {
    _showEma21 = !_showEma21;
    notifyListeners();
  }

  void toggleBoll() {
    _showBoll = !_showBoll;
    notifyListeners();
  }

  void toggleSar() {
    _showSar = !_showSar;
    notifyListeners();
  }

  void toggleRsi() {
    _showRsi = !_showRsi;
    notifyListeners();
  }

  void setChartScale(double value) {
    final nextScale = value.clamp(minChartScale, maxChartScale).toDouble();
    if (_chartScale == nextScale) return;

    _chartScale = nextScale;
    notifyListeners();
  }
}
