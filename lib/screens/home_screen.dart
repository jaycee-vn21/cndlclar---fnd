import 'dart:collection';
import 'dart:math' as math;
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/services/trade_service.dart';
import 'package:cndlclar/services/kline_service.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/providers/sorting_field_provider.dart';
import 'package:cndlclar/screens/individual_token_screen.dart';
import 'package:cndlclar/widgets/token_list_view_section.dart';
import 'package:cndlclar/utils/constants.dart';
import 'package:cndlclar/utils/config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.connectToBackend = true});

  final bool connectToBackend;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TradeService _tradeService = TradeService();
  final KlineService _klineService = KlineService(baseUrl: AppConfig.baseUrl);

  //Hhistorical candles per symbol and interval
  final Map<String, Map<String, List<KlineData>>> _historicalKlines = {};
  final Set<String> _historicalFetchesInFlight = {};
  final Set<String> _historicalFetchesCompleted = {};
  final Set<String> _historicalFetchesQueued = {};
  final Map<String, DateTime> _historicalFetchFailures = {};
  final Queue<_HistoricalFetchRequest> _historicalFetchQueue =
      Queue<_HistoricalFetchRequest>();
  bool _isProcessingHistoricalFetchQueue = false;

  TokensProvider? _tokensProvider;
  IntervalProvider? _intervalProvider;

  static const _historicalFetchRetryDelay = Duration(seconds: 20);
  static const _historicalFetchSpacing = Duration(milliseconds: 120);

  Future<void> _handleTrade({
    required String action, // "buy" or "sell"
    required String symbol,
    int? requestedLeverage,
    double? priceToBuy,
    double? stopLossPercent,
    double? takeProfitPercent,
    double? baseAmount,
  }) async {
    final result = await _tradeService.executeTrade(
      action: action,
      symbol: symbol,
      requestedLeverage: requestedLeverage,
      priceToBuy: priceToBuy,
      stopLossPercent: stopLossPercent,
      takeProfitPercent: takeProfitPercent,
      baseAmount: baseAmount,
    );

    if (result['success'] == true) {
      final data = result['data'];

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${action.toUpperCase()} Successful ✅: ${data['data']['message'] ?? ''}',
            style: TextStyle(color: KColors.textPrimary),
          ),
          backgroundColor: KColors.tradeSuccessfulSnackbar,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trade Failed ❌: ${result['error']}',
            style: TextStyle(color: KColors.textPrimary),
          ),
          backgroundColor: KColors.tradeFailedSnackbar,
        ),
      );
    }
  }

  void _buyPressed(Token token) {
    _handleTrade(
      action: 'buy',
      symbol: token.name,
      requestedLeverage: AppConfig.requestedLaverage,
      stopLossPercent: 1.5,
      takeProfitPercent: 2,
    );
  }

  void _quickBuyPressed(Token token) {
    _handleTrade(
      action: 'buy',
      symbol: token.name,
      requestedLeverage: AppConfig.requestedLaverage,
    );
  }

  void _sellPressed(Token token) {
    _handleTrade(action: 'sell', symbol: token.name);
  }

  void _handleMarketDataChanged() {
    final tokens = _tokensProvider?.tokens ?? const <Token>[];
    if (tokens.isEmpty) return;

    final selectedInterval = _intervalProvider?.selectedInterval ?? '5m';
    final didUpdateLiveCandles = _mergeLiveCandles(tokens, selectedInterval);

    _fetchMissingHistoricalKlines(tokens, selectedInterval);

    if (didUpdateLiveCandles && mounted) {
      setState(() {});
    }
  }

  void _fetchMissingHistoricalKlines(
    List<Token> tokens,
    String selectedInterval,
  ) {
    for (final token in tokens) {
      final key = _historicalKey(token.name, selectedInterval);
      if (_historicalFetchesInFlight.contains(key) ||
          _historicalFetchesCompleted.contains(key) ||
          _historicalFetchesQueued.contains(key) ||
          !_canRetryHistoricalFetch(key)) {
        continue;
      }

      _historicalFetchQueue.add(
        _HistoricalFetchRequest(
          token: token,
          interval: selectedInterval,
          key: key,
        ),
      );
      _historicalFetchesQueued.add(key);
    }

    _processHistoricalFetchQueue();
  }

  bool _canRetryHistoricalFetch(String key) {
    final failedAt = _historicalFetchFailures[key];
    if (failedAt == null) return true;
    return DateTime.now().difference(failedAt) >= _historicalFetchRetryDelay;
  }

  Future<void> _processHistoricalFetchQueue() async {
    if (_isProcessingHistoricalFetchQueue) return;
    _isProcessingHistoricalFetchQueue = true;

    try {
      while (mounted && _historicalFetchQueue.isNotEmpty) {
        final request = _historicalFetchQueue.removeFirst();
        _historicalFetchesQueued.remove(request.key);

        if (_historicalFetchesCompleted.contains(request.key)) {
          continue;
        }

        _historicalFetchesInFlight.add(request.key);

        final hasHistoricalCandles = await _fetchHistoricalKlinesForToken(
          request.token,
          request.interval,
        );

        _historicalFetchesInFlight.remove(request.key);
        if (hasHistoricalCandles) {
          _historicalFetchesCompleted.add(request.key);
          _historicalFetchFailures.remove(request.key);
        } else {
          _historicalFetchFailures[request.key] = DateTime.now();
        }

        await Future<void>.delayed(_historicalFetchSpacing);
      }
    } finally {
      _isProcessingHistoricalFetchQueue = false;
    }
  }

  Future<bool> _fetchHistoricalKlinesForToken(
    Token token,
    String selectedInterval,
  ) async {
    final candles = await _klineService.fetchHistoricalKlines(
      symbol: token.name,
      interval: selectedInterval,
      limit: 50,
    );

    if (!mounted) return candles.isNotEmpty;

    final latestToken = _latestTokenForSymbol(token.name);
    final liveCandle = latestToken == null
        ? null
        : _liveCandleFromToken(latestToken, selectedInterval);

    final updatedCandles = liveCandle == null
        ? _sortedLimitedCandles(candles)
        : _upsertLiveCandle(candles, liveCandle);

    setState(() {
      _historicalKlines[token.name] ??= {};
      _historicalKlines[token.name]![selectedInterval] = updatedCandles;
    });

    return candles.isNotEmpty;
  }

  bool _mergeLiveCandles(List<Token> tokens, String selectedInterval) {
    var didUpdate = false;

    for (final token in tokens) {
      final liveCandle = _liveCandleFromToken(token, selectedInterval);
      if (liveCandle == null) continue;

      final tokenCandles = _historicalKlines.putIfAbsent(token.name, () => {});
      final currentCandles =
          tokenCandles[selectedInterval] ?? const <KlineData>[];

      tokenCandles[selectedInterval] = _upsertLiveCandle(
        currentCandles,
        liveCandle,
      );
      didUpdate = true;
    }

    return didUpdate;
  }

  KlineData? _liveCandleFromToken(Token token, String selectedInterval) {
    final startTime = token.startTime(selectedInterval);
    final close = token.closePrice(selectedInterval);
    if (startTime == null || close <= 0) return null;

    final backendOpen = token.openPrice(selectedInterval);
    final backendHigh = token.highPrice(selectedInterval);
    final backendLow = token.lowPrice(selectedInterval);
    final open = backendOpen > 0
        ? backendOpen
        : _openFromCloseAndChange(close, token.priceChange(selectedInterval));
    final high = math.max(
      backendHigh > 0 ? backendHigh : open,
      math.max(open, close),
    );
    final low = math.min(
      backendLow > 0 ? backendLow : open,
      math.min(open, close),
    );

    return KlineData(
      time: startTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: token.volume(selectedInterval),
      isClosed: token.isIntervalClosed(selectedInterval),
    );
  }

  double _openFromCloseAndChange(double close, double priceChangePercent) {
    final factor = 1 + (priceChangePercent / 100);
    if (factor <= 0) return close;
    return close / factor;
  }

  List<KlineData> _upsertLiveCandle(
    List<KlineData> candles,
    KlineData liveCandle,
  ) {
    final updated = _sortedLimitedCandles(candles);
    final liveTime = liveCandle.time.millisecondsSinceEpoch;
    final existingIndex = updated.indexWhere(
      (candle) => candle.time.millisecondsSinceEpoch == liveTime,
    );

    if (existingIndex == -1) {
      updated.add(liveCandle);
      return _sortedLimitedCandles(updated);
    }

    final existing = updated[existingIndex];
    updated[existingIndex] = KlineData(
      time: existing.time,
      open: existing.open,
      high: math.max(existing.high, liveCandle.high),
      low: math.min(existing.low, liveCandle.low),
      close: liveCandle.close,
      volume: liveCandle.volume > 0 ? liveCandle.volume : existing.volume,
      isClosed: liveCandle.isClosed,
    );

    return updated;
  }

  List<KlineData> _sortedLimitedCandles(List<KlineData> candles) {
    final sorted = List<KlineData>.from(candles)
      ..sort((a, b) => a.time.compareTo(b.time));
    if (sorted.length <= 50) return sorted;
    return sorted.sublist(sorted.length - 50);
  }

  String _historicalKey(String symbol, String interval) {
    return '$symbol|$interval';
  }

  Token? _latestTokenForSymbol(String symbol) {
    final tokens = _tokensProvider?.tokens ?? const <Token>[];
    for (final token in tokens) {
      if (token.name == symbol) return token;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    _tokensProvider = Provider.of<TokensProvider>(context, listen: false);
    _intervalProvider = Provider.of<IntervalProvider>(context, listen: false);

    if (widget.connectToBackend) {
      _tokensProvider?.connectToBackend(AppConfig.baseUrl);
    }

    _tokensProvider?.addListener(_handleMarketDataChanged);
    _intervalProvider?.addListener(_handleMarketDataChanged);
  }

  @override
  void dispose() {
    _tokensProvider?.removeListener(_handleMarketDataChanged);
    _intervalProvider?.removeListener(_handleMarketDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      appBar: AppBar(
        title: const Text('CndlClar', style: KTextStyles.appBarTitle),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: [
          //Set sorting
          IconButton(
            onPressed: () {
              final sortingFieldProvider = Provider.of<SortingFieldProvider>(
                context,
                listen: false,
              );
              sortingFieldProvider.sortingField == 'priceChange'
                  ? sortingFieldProvider.setSortingField('tickerPriceChange1h')
                  : sortingFieldProvider.setSortingField('priceChange');
            },
            icon: const Icon(
              KIcons.setSortingField,
              size: KSizes.navIconSize,
              color: KColors.textPrimary,
            ),
          ),
        ],
      ),
      body: TokenListViewSection(
        showList: true,
        historicalKlines: _historicalKlines,
        onTokenTap: (token) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => IndividualTokenScreen(
                token: token,
                historicalKlines: _historicalKlines,
                onBuyPressed: () => _buyPressed(token),
                onQuickBuyPressed: () => _quickBuyPressed(token),
                onSellPressed: () => _sellPressed(token),
              ),
            ),
          );
        },
        onBuyPressed: _buyPressed,
        onQuickBuyPressed: _quickBuyPressed,
        onSellPressed: _sellPressed,
      ),
    );
  }
}

class _HistoricalFetchRequest {
  const _HistoricalFetchRequest({
    required this.token,
    required this.interval,
    required this.key,
  });

  final Token token;
  final String interval;
  final String key;
}
