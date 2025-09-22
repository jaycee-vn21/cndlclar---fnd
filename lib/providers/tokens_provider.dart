import 'dart:math';
import 'package:cndlclar/models/token.dart';
import 'package:flutter/material.dart';

class TokensProvider with ChangeNotifier {
  List<Token> _tokens = [];
  String selectedInterval = '1m';

  Map<String, List<double>> tokenSparklines = {};
  Map<String, Map<String, dynamic>> tokenIndicators = {};

  final Random _random = Random();

  TokensProvider() {
    _initializeDummyTokens();
  }

  List<Token> getTokens() => _tokens;

  void setSelectedInterval(String interval) {
    selectedInterval = interval;
    notifyListeners();
  }

  // --- Dummy tokens ---
  void _initializeDummyTokens() {
    _tokens = [
      Token(
        name: "BTC",
        price: 30000,
        change1d: 1.2,
        changeSelectedInterval: 0.5,
        volume: 45000000000,
        marketCap: 550000000000,
      ),
      Token(
        name: "ETH",
        price: 2000,
        change1d: -0.8,
        changeSelectedInterval: 0.3,
        volume: 20000000000,
        marketCap: 240000000000,
      ),
      Token(
        name: "SOL",
        price: 35,
        change1d: 2.1,
        changeSelectedInterval: 1.0,
        volume: 5000000000,
        marketCap: 12000000000,
      ),
    ];

    for (final token in _tokens) {
      tokenSparklines[token.name] = _generateTrendSparkline(token.price);
      tokenIndicators[token.name] = _generateTrendIndicators(
        token.price,
        bullish: _random.nextBool(),
      );
    }
  }

  // Smooth trend-like sparkline
  List<double> _generateTrendSparkline(
    double basePrice, {
    bool bullish = true,
  }) {
    double last = basePrice;
    final trendFactor = bullish ? 0.002 : -0.002;
    return List.generate(20, (index) {
      final volatility = (_random.nextDouble() - 0.5) * basePrice * 0.01;
      final next = last * (1 + trendFactor) + volatility;
      last = next;
      return next;
    });
  }

  // Trend-based indicators
  Map<String, dynamic> _generateTrendIndicators(
    double price, {
    bool bullish = true,
  }) {
    return {
      "ema": {
        "value":
            "${(price / 1000).toStringAsFixed(1)}/${(price / 1050).toStringAsFixed(1)}",
        "bullish": bullish,
      },
      "rsi": {
        "value": (bullish ? 50 + _random.nextInt(30) : 20 + _random.nextInt(30))
            .toString(),
        "bullish": bullish,
      },
      "macd": {
        "value": (price * 0.0001 * (_random.nextDouble() + (bullish ? 0.5 : 0)))
            .toStringAsFixed(2),
        "bullish": bullish,
      },
      "stoch": {
        "value": (bullish ? 50 + _random.nextInt(50) : _random.nextInt(50))
            .toString(),
        "bullish": bullish,
      },
    };
  }

  // Update dummy data periodically
  void updateDummyData() {
    for (final token in _tokens) {
      final bullish = _random.nextBool();

      // Update sparkline
      final data = tokenSparklines[token.name]!;
      final last = data.last;
      final nextPoint =
          last * (1 + (bullish ? 0.002 : -0.002)) +
          (_random.nextDouble() - 0.5) * token.price * 0.01;
      tokenSparklines[token.name] = [...data.skip(1), nextPoint];

      // Update indicators
      tokenIndicators[token.name] = _generateTrendIndicators(
        token.price,
        bullish: bullish,
      );
    }
    notifyListeners();
  }

  // Replace with real backend
  void updateFromBackend(List<Map<String, dynamic>> backendTokens) {
    _tokens = backendTokens.map((e) => Token.fromMap(e)).toList();

    for (final token in _tokens) {
      tokenSparklines[token.name] ??= _generateTrendSparkline(token.price);
      tokenIndicators[token.name] ??= _generateTrendIndicators(
        token.price,
        bullish: _random.nextBool(),
      );
    }

    notifyListeners();
  }
}
