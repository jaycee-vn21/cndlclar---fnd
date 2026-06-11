import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cndlclar/models/demo_paper_account.dart';
import 'package:cndlclar/models/short_term_buy_candidate.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/models/indicator.dart';
import 'package:cndlclar/services/demo_paper_account_service.dart';
import 'package:cndlclar/services/socket_manager.dart';
import 'package:cndlclar/utils/config.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class TokensProvider with ChangeNotifier {
  io.Socket? _socket;
  List<Token> _tokens = [];
  List<ShortTermBuyCandidate> _shortTermBuyCandidates = [];
  DemoPaperAccount _demoPaperAccount = DemoPaperAccount.initial();
  DateTime? _shortTermBuyCandidatesUpdatedAt;
  bool _isDemoPaperAccountLoading = false;

  // Stores sparkline per token and interval for quick updates
  Map<String, Map<String, List<double>>> tokenSparklines = {};

  final Random _random = Random();

  // Connection flag
  bool isConnected = false;

  List<Token> get tokens => _tokens;
  List<ShortTermBuyCandidate> get shortTermBuyCandidates =>
      _shortTermBuyCandidates;
  DateTime? get shortTermBuyCandidatesUpdatedAt =>
      _shortTermBuyCandidatesUpdatedAt;
  DemoPaperAccount get demoPaperAccount => _demoPaperAccount;
  bool get isDemoPaperAccountLoading => _isDemoPaperAccountLoading;

  Map<String, ShortTermBuyCandidate> get shortTermBuyCandidatesBySymbol => {
    for (final candidate in _shortTermBuyCandidates)
      candidate.tokenName: candidate,
  };

  // --------------------------
  // --- SOCKET / BACKEND DATA ---
  // --------------------------
  void connectToBackend(String socketUrl) {
    if (_socket != null) return;

    final socket = SocketManager(socketUrl).connectToSocket();
    _socket = socket;

    socket.on('disconnect', (_) {
      isConnected = false;
      notifyListeners();
    });

    socket.on('klinesCombined', (backendTokensData) {
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

    socket.on('shortTermBuyCandidates', _handleShortTermBuyCandidates);
    socket.on('demoPaperAccount', _handleDemoPaperAccount);
  }

  Future<void> fetchDemoPaperAccount() async {
    if (_isDemoPaperAccountLoading) return;

    _isDemoPaperAccountLoading = true;
    notifyListeners();

    final service = DemoPaperAccountService(baseUrl: AppConfig.baseUrl);
    final account = await service.fetchDemoPaperAccount();

    if (account != null) {
      _demoPaperAccount = account;
    }

    _isDemoPaperAccountLoading = false;
    notifyListeners();
  }

  void _handleShortTermBuyCandidates(dynamic payload) {
    if (payload is! Map) return;

    final data = Map<String, dynamic>.from(payload);
    final rawCandidates = data['candidates'];
    final parsedCandidates = <ShortTermBuyCandidate>[];

    if (rawCandidates is List) {
      for (final rawCandidate in rawCandidates) {
        if (rawCandidate is Map) {
          parsedCandidates.add(
            ShortTermBuyCandidate.fromMap(
              Map<String, dynamic>.from(rawCandidate),
            ),
          );
        }
      }
    }

    _shortTermBuyCandidates = parsedCandidates;
    _shortTermBuyCandidatesUpdatedAt = DateTime.tryParse(
      data['generatedAt']?.toString() ?? '',
    );
    notifyListeners();
  }

  void _handleDemoPaperAccount(dynamic payload) {
    if (payload is! Map) return;

    _demoPaperAccount = DemoPaperAccount.fromMap(
      Map<String, dynamic>.from(payload),
    );
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
