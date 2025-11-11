import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/models/indicator.dart';
import 'package:cndlclar/services/socket_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class TokensProvider with ChangeNotifier {
  late io.Socket _socket;
  List<Token> _tokens = [];

  // Stores sparkline per token and interval for quick updates
  Map<String, Map<String, List<double>>> tokenSparklines = {};

  final Random _random = Random();

  // Connection flag
  bool isConnected = false;

  TokensProvider() {
    // Initialize dummy tokens for UI preview before real backend
    _initializeDummyTokens();
  }

  List<Token> get tokens => _tokens;

  // --------------------------
  // --- DUMMY DATA METHODS ---
  // --------------------------
  void _initializeDummyTokens() {
    _tokens = [
      _createDummyToken("BTC", 30000, 550000000000, 1),
      _createDummyToken("ETH", 2000, 240000000000, 2),
      _createDummyToken("SOL", 35, 12000000000, 3),
    ];
  }

  Token _createDummyToken(
    String name,
    double price,
    double marketCap,
    double tickerPriceChange1h,
  ) {
    const intervals = ["1m", "5m", "15m", "1h"];

    final closePricePerInterval = <String, double>{};
    final priceChangePercentPerInterval = <String, double>{};
    final volumePerInterval = <String, double>{};
    final netVolumePerInterval = <String, double>{};
    final intervalStartTimes = <String, DateTime>{};
    final sparklineData = <String, List<double>>{};
    final sparklineDataOriginal = <String, List<double>>{};

    for (final interval in intervals) {
      closePricePerInterval[interval] = price;
      priceChangePercentPerInterval[interval] = 0;
      volumePerInterval[interval] = 0;
      netVolumePerInterval[interval] = 0;
      intervalStartTimes[interval] = DateTime.now();

      final dummySparkline = _generateTrendSparkline(price);
      sparklineData[interval] = List<double>.from(dummySparkline);
      sparklineDataOriginal[interval] = List<double>.from(dummySparkline);
    }

    final indicators = _generateDummyIndicators(price);

    tokenSparklines[name] = sparklineData;

    return Token(
      name: name,
      marketCap: marketCap,
      indicators: indicators,
      tickerPriceChange1h: tickerPriceChange1h,
      closePricePerInterval: closePricePerInterval,
      priceChangePercentPerInterval: priceChangePercentPerInterval,
      volumePerInterval: volumePerInterval,
      netVolumePerInterval: netVolumePerInterval,
      intervalStartTimes: intervalStartTimes,
      sparklineData: sparklineData,
      sparklineDataOriginal: sparklineDataOriginal,
    );
  }

  // --------------------------
  // --- SOCKET / BACKEND DATA ---
  // --------------------------
  void connectToBackend(String socketUrl) {
    _socket = SocketManager(socketUrl).connectToSocket();

    _socket.on('klinesCombined', (backendTokensData) {
      final List<Token> updatedTokens = [];

      for (final tokenMap in backendTokensData) {
        final token = Token.fromMap(tokenMap);

        // If token already exists, update sparkline instead of replacing
        final existing = _tokens.firstWhere(
          (t) => t.name == token.name,
          orElse: () => token,
        );

        // Update sparkline trend per interval
        token.sparklineData.forEach((interval, list) {
          final newPrice = token.closePrice(interval);

          if (existing.sparklineData[interval] != null &&
              existing.sparklineData[interval]!.isNotEmpty) {
            // Rolling update: shift left, append new price
            final oldData = existing.sparklineData[interval]!;
            final newData = [...oldData.skip(1), newPrice];
            token.sparklineData[interval] = newData;
            token.sparklineDataOriginal[interval] = newData;
          } else {
            // Initialize with dummy if empty
            final dummy = _generateTrendSparkline(newPrice);
            token.sparklineData[interval] = List<double>.from(dummy);
            token.sparklineDataOriginal[interval] = List<double>.from(dummy);
          }
        });

        // Preserve dummy indicators if backend doesn’t provide
        if (token.indicators.isEmpty) {
          token.indicators = _generateDummyIndicators(token.closePrice("1m"));
        }

        tokenSparklines[token.name] = token.sparklineData;
        updatedTokens.add(token);
      }

      _tokens = updatedTokens;
      isConnected = true;
      notifyListeners();
    });
  }

  // --------------------------
  // --- UPDATE DUMMY DATA FOR LIVE PREVIEW ---
  // --------------------------
  void updateDummyData() {
    for (final token in _tokens) {
      token.sparklineData.forEach((interval, data) {
        double last = data.last;
        final trendFactor = 0.002;
        final volatility =
            (_random.nextDouble() - 0.5) * token.closePrice(interval) * 0.01;
        final next = last * (1 + trendFactor) + volatility;

        final newData = [...data.skip(1), next];
        token.sparklineData[interval] = newData;
      });

      token.indicators = _generateDummyIndicators(token.closePrice("1m"));
    }

    notifyListeners();
  }

  // --------------------------
  // --- PRIVATE HELPERS FOR DUMMY SPARKLINE AND INDICATORS---
  // --------------------------
  List<double> _generateTrendSparkline(double basePrice, {int length = 20}) {
    double last = basePrice;
    const trendFactor = 0.002;
    return List.generate(length, (index) {
      final volatility = (_random.nextDouble() - 0.5) * basePrice * 0.01;
      final next = last * (1 + trendFactor) + volatility;
      last = next;
      return next;
    });
  }

  List<Indicator> _generateDummyIndicators(double price) {
    return [
      Indicator.fromKey(
        key: "ema",
        rawValue:
            "${(price / 1000).toStringAsFixed(1)}/${(price / 1050).toStringAsFixed(1)}",
        bullish: _random.nextBool(),
        label: "EMA 9/21",
      ),
      Indicator.fromKey(
        key: "ema",
        rawValue:
            "${(price / 1100).toStringAsFixed(1)}/${(price / 1150).toStringAsFixed(1)}",
        bullish: _random.nextBool(),
        label: "EMA 21/50",
      ),
      Indicator.fromKey(
        key: "rsi",
        rawValue: (_random.nextInt(100)).toString(),
        bullish: _random.nextBool(),
      ),
      Indicator.fromKey(
        key: "macd",
        rawValue: (price * 0.0001 * (_random.nextDouble() + 0.5))
            .toStringAsFixed(2),
        bullish: _random.nextBool(),
      ),
      Indicator.fromKey(
        key: "stoch",
        rawValue: (_random.nextInt(100)).toString(),
        bullish: _random.nextBool(),
      ),
    ];
  }
}
