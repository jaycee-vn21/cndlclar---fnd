import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/models/indicator.dart';

class TokensProvider with ChangeNotifier {
  List<Token> _tokens = [];
  String selectedInterval = '1m';

  // Stores sparkline data per token
  Map<String, List<double>> tokenSparklines = {};

  final Random _random = Random();

  TokensProvider() {
    // Initialize with dummy data for visual testing
    _initializeDummyTokens();
  }

  List<Token> getTokens() => _tokens;

  void setSelectedInterval(String interval) {
    selectedInterval = interval;
    notifyListeners();
  }

  // --------------------------
  // --- DUMMY DATA METHODS ---
  // --------------------------
  // Only needed for testing / UI preview before real backend
  void _initializeDummyTokens() {
    _tokens = [
      Token(
        name: "BTC",
        price: 30000,
        change1d: 1.2,
        changeSelectedInterval: 0.5,
        volume: 45000000000,
        marketCap: 550000000000,
        indicators: _generateTrendIndicators(30000, bullish: true),
      ),
      Token(
        name: "ETH",
        price: 2000,
        change1d: -0.8,
        changeSelectedInterval: 0.3,
        volume: 20000000000,
        marketCap: 240000000000,
        indicators: _generateTrendIndicators(2000, bullish: false),
      ),
      Token(
        name: "SOL",
        price: 35,
        change1d: 2.1,
        changeSelectedInterval: 1.0,
        volume: 5000000000,
        marketCap: 12000000000,
        indicators: _generateTrendIndicators(35, bullish: true),
      ),
    ];

    // Initialize sparkline dummy data
    for (final token in _tokens) {
      tokenSparklines[token.name] = _generateTrendSparkline(token.price);
    }
  }

  // Generate smooth trend-like sparkline (dummy)
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

  // Generate trend-based dummy indicators
  List<Indicator> _generateTrendIndicators(
    double price, {
    bool bullish = true,
  }) {
    final List<Indicator> indicators = [];

    // Example: multiple EMA indicators
    indicators.add(
      Indicator.fromKey(
        key: "ema",
        rawValue:
            "${(price / 1000).toStringAsFixed(1)}/${(price / 1050).toStringAsFixed(1)}",
        bullish: bullish,
        label: "EMA 9/21",
      ),
    );
    indicators.add(
      Indicator.fromKey(
        key: "ema",
        rawValue:
            "${(price / 1100).toStringAsFixed(1)}/${(price / 1150).toStringAsFixed(1)}",
        bullish: bullish,
        label: "EMA 21/50",
      ),
    );

    // Other indicators
    indicators.add(
      Indicator.fromKey(
        key: "rsi",
        rawValue: bullish ? 50 + _random.nextInt(30) : 20 + _random.nextInt(30),
        bullish: bullish,
      ),
    );

    indicators.add(
      Indicator.fromKey(
        key: "macd",
        rawValue:
            (price * 0.0001 * (_random.nextDouble() + (bullish ? 0.5 : 0)))
                .toStringAsFixed(2),
        bullish: bullish,
      ),
    );

    indicators.add(
      Indicator.fromKey(
        key: "stoch",
        rawValue: bullish ? 50 + _random.nextInt(50) : _random.nextInt(50),
        bullish: bullish,
      ),
    );

    // -----------------------------
    // NOTE: All above is dummy/testing data.
    // For real backend:
    // - Remove this method completely
    // - Use Indicator.fromMap to parse indicators from backend
    // -----------------------------

    return indicators;
  }

  // Update dummy data periodically (for live preview in UI)
  void updateDummyData() {
    final updatedTokens = <Token>[];

    for (final token in _tokens) {
      final bullish = _random.nextBool();

      // Update sparkline
      final data = tokenSparklines[token.name]!;
      final last = data.last;
      final nextPoint =
          last * (1 + (bullish ? 0.002 : -0.002)) +
          (_random.nextDouble() - 0.5) * token.price * 0.01;
      tokenSparklines[token.name] = [...data.skip(1), nextPoint];

      // Recreate token with updated dummy indicators
      updatedTokens.add(
        Token(
          name: token.name,
          price: token.price,
          change1d: token.change1d,
          changeSelectedInterval: token.changeSelectedInterval,
          volume: token.volume,
          marketCap: token.marketCap,
          indicators: _generateTrendIndicators(token.price, bullish: bullish),
        ),
      );
    }

    _tokens = updatedTokens;
    notifyListeners();
  }

  // -----------------------------
  // --- REAL BACKEND METHODS ---
  // -----------------------------
  void updateFromBackend(List<Map<String, dynamic>> backendTokens) {
    _tokens = backendTokens.map((e) => Token.fromMap(e)).toList();

    // Initialize sparkline for new tokens if missing
    for (final token in _tokens) {
      tokenSparklines[token.name] ??= _generateTrendSparkline(
        token.price,
      ); // optional dummy sparkline
    }

    // -----------------------------
    // NOTE: When real backend exists:
    // - Do NOT call _generateTrendIndicators
    // - Use token.indicators directly from backend
    // -----------------------------

    notifyListeners();
  }
}
