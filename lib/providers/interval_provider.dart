import 'package:flutter/material.dart';

// Interval Provider
class IntervalProvider with ChangeNotifier {
  String _interval = '5m';
  String get selectedInterval => _interval;

  void setInterval(String newInterval) {
    _interval = newInterval;
    notifyListeners();
  }
}
