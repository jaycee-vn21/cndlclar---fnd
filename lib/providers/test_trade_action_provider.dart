import 'package:flutter/material.dart';

class TestTradeActionProvider with ChangeNotifier {
  String _action = 'buy';
  String get action => _action;

  void updateAction() {
    _action = _action == 'buy' ? 'sell' : 'buy';
    notifyListeners();
  }
}
