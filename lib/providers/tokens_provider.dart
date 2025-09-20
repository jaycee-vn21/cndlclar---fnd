import 'package:cndlclar/models/token.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class TokensProvider with ChangeNotifier {
  final List<Token> _tokens = [];

  String selectedInterval = '1h'; // default selected interval

  TokensProvider() {
    _generateDummyTokens();
  }

  List<Token> getTokens() {
    return _tokens;
  }

  void setSelectedInterval(String interval) {
    selectedInterval = interval;
    // regenerate dummy data for selected interval to simulate live data
    _generateDummyTokens();
    notifyListeners();
  }

  void _generateDummyTokens() {
    _tokens.clear();
    final random = Random();

    for (int i = 0; i < 10; i++) {
      final price = 1000 + random.nextDouble() * 50000;
      final change1d = -5 + random.nextDouble() * 10;
      final changeSelected = -2 + random.nextDouble() * 4;
      final volume = 1000000 + random.nextDouble() * 5000000;
      final marketCap = 50000000 + random.nextDouble() * 100000000;

      _tokens.add(
        Token(
          name: 'TOKEN$i',
          price: price,
          change1d: change1d,
          changeSelectedInterval: changeSelected,
          volume: volume,
          marketCap: marketCap,
        ),
      );
    }
  }
}
