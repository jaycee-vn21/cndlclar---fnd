import 'package:flutter/material.dart';

class CurrentScreenIndexProvider extends ChangeNotifier {
  int _currentScreenIndex = 0;

  void setIndex(int index) {
    _currentScreenIndex = index;
    notifyListeners();
  }

  int get currentScreenIndex => _currentScreenIndex;
}
