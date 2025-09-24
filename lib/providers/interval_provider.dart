import 'package:flutter/material.dart';

// Interval Provider
class IntervalProvider with ChangeNotifier {
  String _interval = '5m';
  String get selectedInterval => _interval;

  final Map<String, DateTime> _intervalStartTimes = {};

  void updateIntervalStartTime(String interval, DateTime startTime) {
    _intervalStartTimes[interval] = startTime;
    notifyListeners();
  }

  DateTime? getIntervalStartTime(String interval) =>
      _intervalStartTimes[interval];

  void setInterval(String newInterval) {
    _interval = newInterval;
    notifyListeners();
  }
}
