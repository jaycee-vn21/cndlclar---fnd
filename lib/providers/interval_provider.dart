import 'package:flutter/material.dart';

// Interval Provider
class IntervalProvider with ChangeNotifier {
  String _interval = '1m';
  String get interval => _interval;

  void setInterval(String newInterval) {
    _interval = newInterval;
    notifyListeners();
  }
}
