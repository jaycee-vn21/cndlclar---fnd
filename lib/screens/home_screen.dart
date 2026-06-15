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
import 'package:cndlclar/providers/trade_mode_provider.dart';
import 'package:cndlclar/screens/individual_token_screen.dart';
import 'package:cndlclar/widgets/token_list_view_section.dart';
import 'package:cndlclar/utils/constants.dart';
import 'package:cndlclar/utils/config.dart';

enum _TokenFeedMode { all, signals }

enum _SignalFeedFilter { all, setup, elastic, structure }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.connectToBackend = true,
    this.showCharts = true,
    this.showTradeButtons = true,
    this.title = 'CndlClar',
  });

  final bool connectToBackend;
  final bool showCharts;
  final bool showTradeButtons;
  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TradeService _tradeService = TradeService();
  final KlineService _klineService = KlineService(baseUrl: AppConfig.baseUrl);
  final TextEditingController _searchController = TextEditingController();

  //Hhistorical candles per symbol and interval
  final Map<String, Map<String, List<KlineData>>> _historicalKlines = {};
  final Set<String> _historicalFetchesInFlight = {};
  final Set<String> _historicalFetchesCompleted = {};
  final Set<String> _historicalFetchesQueued = {};
  final Map<String, DateTime> _historicalFetchFailures = {};
  final Map<String, DateTime> _historicalFetchCompletedAt = {};
  final Queue<_HistoricalFetchRequest> _historicalFetchQueue =
      Queue<_HistoricalFetchRequest>();
  bool _isProcessingHistoricalFetchQueue = false;

  TokensProvider? _tokensProvider;
  IntervalProvider? _intervalProvider;
  _TokenFeedMode _feedMode = _TokenFeedMode.all;
  _SignalFeedFilter _signalFilter = _SignalFeedFilter.all;
  bool _isSearchOpen = false;
  String _searchQuery = '';

  static const _historicalFetchRetryDelay = Duration(seconds: 20);
  static const _historicalStaleRefreshDelay = Duration(seconds: 15);
  static const _historicalFetchSpacing = Duration(milliseconds: 120);
  static const _liveCandleBoundaryTolerance = Duration(seconds: 5);

  Future<void> _handleTrade({
    required String action, // "buy" or "sell"
    required String symbol,
    String? actionLabel,
    double? currentPrice,
    int? requestedLeverage,
    double? priceToBuy,
    double? stopLossPercent,
    double? takeProfitPercent,
    double? baseAmount,
    double? autoSellProfitPercent,
    String? interval,
  }) async {
    final isDemoTradeMode = context.read<TradeModeProvider>().isDemoMode;
    final result = await _tradeService.executeTrade(
      action: action,
      symbol: symbol,
      demoMode: isDemoTradeMode,
      currentPrice: currentPrice,
      requestedLeverage: requestedLeverage,
      priceToBuy: priceToBuy,
      stopLossPercent: stopLossPercent,
      takeProfitPercent: takeProfitPercent,
      baseAmount: baseAmount,
      autoSellProfitPercent: autoSellProfitPercent,
      interval: interval,
    );

    if (result['success'] == true) {
      final data = result['data'];
      final isAccepted = data['status']?.toString() == 'accepted';
      final statusLabel = isAccepted ? 'Accepted' : 'Successful';
      final displayAction = actionLabel ?? action.toUpperCase();
      final modeLabel = isDemoTradeMode ? 'Demo' : 'Real';

      if (mounted) {
        if (isDemoTradeMode) {
          await context.read<TokensProvider>().fetchDemoPaperAccount();
        } else {
          await context.read<TokensProvider>().fetchRealTradeAccount();
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$modeLabel $displayAction $statusLabel ✅: ${data['data']['message'] ?? ''}',
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
      currentPrice: _tradeCurrentPrice(token),
      requestedLeverage: AppConfig.requestedLaverage,
      stopLossPercent: 1.5,
      takeProfitPercent: 2,
    );
  }

  void _quickBuyPressed(Token token) {
    _handleTrade(
      action: 'buy',
      symbol: token.name,
      currentPrice: _tradeCurrentPrice(token),
      requestedLeverage: AppConfig.requestedLaverage,
    );
  }

  void _sellPressed(Token token) {
    _handleTrade(
      action: 'sell',
      symbol: token.name,
      currentPrice: _tradeCurrentPrice(token),
    );
  }

  void _ema7LimitOcoPressed(Token token) {
    _handleTrade(
      action: 'ema7-limit-buy-oco',
      actionLabel: 'EMA7 Limit + OCO',
      symbol: token.name,
      currentPrice: _tradeCurrentPrice(token),
      requestedLeverage: AppConfig.requestedLaverage,
      stopLossPercent: 1.5,
      takeProfitPercent: 2,
    );
  }

  void _marketAutoClosePressed(Token token) {
    _handleTrade(
      action: 'market-buy-auto-close',
      actionLabel: '5m Auto Sell',
      symbol: token.name,
      currentPrice: _tradeCurrentPrice(token),
      requestedLeverage: AppConfig.requestedLaverage,
      stopLossPercent: 1.5,
      takeProfitPercent: 2,
      autoSellProfitPercent: 0.45,
      interval: '5m',
    );
  }

  double _tradeCurrentPrice(Token token) {
    final selectedInterval = _intervalProvider?.selectedInterval ?? '5m';
    final selectedPrice = token.closePrice(selectedInterval);
    if (selectedPrice > 0) return selectedPrice;

    final oneMinutePrice = token.closePrice('1m');
    if (oneMinutePrice > 0) return oneMinutePrice;

    final fiveMinutePrice = token.closePrice('5m');
    if (fiveMinutePrice > 0) return fiveMinutePrice;

    for (final interval in const ['15m', '30m', '1h', '1d']) {
      final price = token.closePrice(interval);
      if (price > 0) return price;
    }

    return 0;
  }

  void _handleMarketDataChanged() {
    final tokens = _tokensProvider?.tokens ?? const <Token>[];
    if (tokens.isEmpty) return;

    final selectedInterval = _intervalProvider?.selectedInterval ?? '5m';
    final intervalsToSync = <String>{'5m', '30m', selectedInterval};
    var didUpdateLiveCandles = false;

    for (final interval in intervalsToSync) {
      didUpdateLiveCandles =
          _mergeLiveCandles(tokens, interval) || didUpdateLiveCandles;
      _fetchMissingHistoricalKlines(tokens, interval);
    }

    if (didUpdateLiveCandles && mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureHistoricalKlinesForToken(Token token) async {
    final selectedInterval = _intervalProvider?.selectedInterval ?? '5m';
    final needsRefresh = _shouldRefreshHistoricalForLiveCandle(
      token,
      selectedInterval,
    );
    if (_historicalKlines[token.name]?[selectedInterval]?.isNotEmpty == true &&
        !needsRefresh) {
      return;
    }

    final key = _historicalKey(token.name, selectedInterval);
    if (_historicalFetchesInFlight.contains(key)) return;
    if (needsRefresh) _invalidateHistoricalFetch(key);

    _historicalFetchesInFlight.add(key);
    try {
      final hasHistoricalCandles = await _fetchHistoricalKlinesForToken(
        token,
        selectedInterval,
      );

      if (hasHistoricalCandles) {
        _markHistoricalFetchCompleted(key);
      } else {
        _historicalFetchFailures[key] = DateTime.now();
      }
    } finally {
      _historicalFetchesInFlight.remove(key);
    }
  }

  Future<void> _openTokenScreen(Token token) async {
    if (!widget.showCharts) {
      await _ensureHistoricalKlinesForToken(token);
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IndividualTokenScreen(
          token: token,
          historicalKlines: _historicalKlines,
          onEma7LimitOcoPressed: () => _ema7LimitOcoPressed(token),
          onMarketAutoClosePressed: () => _marketAutoClosePressed(token),
          onBuyPressed: () => _buyPressed(token),
          onQuickBuyPressed: () => _quickBuyPressed(token),
          onSellPressed: () => _sellPressed(token),
        ),
      ),
    );
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
          _markHistoricalFetchCompleted(request.key);
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
      final key = _historicalKey(token.name, selectedInterval);

      if (_shouldRefreshHistoricalForLiveCandle(
        token,
        selectedInterval,
        candles: currentCandles,
      )) {
        _invalidateHistoricalFetch(key, respectCooldown: true);
      }

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
      volumeUsdt: token.volume(selectedInterval),
      netVolumeUsdt: token.netVolume(selectedInterval),
      isClosed: token.isIntervalClosed(selectedInterval),
    );
  }

  bool _shouldRefreshHistoricalForLiveCandle(
    Token token,
    String selectedInterval, {
    List<KlineData>? candles,
  }) {
    final liveStartTime = token.startTime(selectedInterval);
    final intervalDuration = _intervalDuration(selectedInterval);
    if (liveStartTime == null || intervalDuration == null) return false;

    final currentCandles =
        candles ?? _historicalKlines[token.name]?[selectedInterval];
    if (currentCandles == null || currentCandles.isEmpty) return false;

    final sortedCandles = _sortedLimitedCandles(currentCandles);
    if (_hasCandleTimeGap(sortedCandles, intervalDuration)) return true;

    final latestCachedCandle = sortedCandles.last;
    final liveGap = liveStartTime.difference(latestCachedCandle.time);

    if (liveGap <= Duration.zero) return false;
    if (liveGap > intervalDuration + _liveCandleBoundaryTolerance) return true;

    final crossedIntoNextCandle =
        liveGap + _liveCandleBoundaryTolerance >= intervalDuration;
    return crossedIntoNextCandle && !latestCachedCandle.isClosed;
  }

  bool _invalidateHistoricalFetch(String key, {bool respectCooldown = false}) {
    if (respectCooldown && _wasHistoricalFetchedRecently(key)) return false;

    _historicalFetchesCompleted.remove(key);
    _historicalFetchFailures.remove(key);
    return true;
  }

  void _markHistoricalFetchCompleted(String key) {
    _historicalFetchesCompleted.add(key);
    _historicalFetchCompletedAt[key] = DateTime.now();
    _historicalFetchFailures.remove(key);
  }

  bool _wasHistoricalFetchedRecently(String key) {
    final completedAt = _historicalFetchCompletedAt[key];
    if (completedAt == null) return false;
    return DateTime.now().difference(completedAt) <
        _historicalStaleRefreshDelay;
  }

  bool _hasCandleTimeGap(
    List<KlineData> sortedCandles,
    Duration intervalDuration,
  ) {
    for (var index = 1; index < sortedCandles.length; index += 1) {
      final gap = sortedCandles[index].time.difference(
        sortedCandles[index - 1].time,
      );
      if (gap > intervalDuration + _liveCandleBoundaryTolerance) {
        return true;
      }
    }

    return false;
  }

  Duration? _intervalDuration(String interval) {
    if (interval.length < 2) return null;

    final value = int.tryParse(interval.substring(0, interval.length - 1));
    if (value == null) return null;

    if (interval.endsWith('m')) return Duration(minutes: value);
    if (interval.endsWith('h')) return Duration(hours: value);
    if (interval.endsWith('d')) return Duration(days: value);
    return null;
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

    updated[existingIndex] = liveCandle;

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
    _searchController.dispose();
    super.dispose();
  }

  String _formatSignalsUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return 'waiting';

    final local = updatedAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  String _signalFilterValue(_SignalFeedFilter filter) {
    switch (filter) {
      case _SignalFeedFilter.setup:
        return 'normal';
      case _SignalFeedFilter.elastic:
        return 'elastic';
      case _SignalFeedFilter.structure:
        return 'structure';
      case _SignalFeedFilter.all:
        return 'all';
    }
  }

  String _signalFilterLabel(_SignalFeedFilter filter) {
    switch (filter) {
      case _SignalFeedFilter.setup:
        return 'setup';
      case _SignalFeedFilter.elastic:
        return 'elastic';
      case _SignalFeedFilter.structure:
        return 'structure';
      case _SignalFeedFilter.all:
        return 'signals';
    }
  }

  int _signalCountForFilter(TokensProvider tokensProvider) {
    switch (_signalFilter) {
      case _SignalFeedFilter.setup:
        return tokensProvider.shortTermBuyCandidates
            .where((candidate) => candidate.hasSetupSignal)
            .length;
      case _SignalFeedFilter.elastic:
        return tokensProvider.shortTermBuyCandidates
            .where((candidate) => candidate.hasElasticSignal)
            .length;
      case _SignalFeedFilter.structure:
        return tokensProvider.shortTermBuyCandidates
            .where((candidate) => candidate.hasStructureSignal)
            .length;
      case _SignalFeedFilter.all:
        return tokensProvider.shortTermBuyCandidates.length;
    }
  }

  void _setSignalFilter(
    _SignalFeedFilter nextFilter,
    SortingFieldProvider sortingFieldProvider,
  ) {
    setState(() => _signalFilter = nextFilter);

    switch (nextFilter) {
      case _SignalFeedFilter.setup:
        sortingFieldProvider.setSortingField(SortingFields.setupSignalScore);
        break;
      case _SignalFeedFilter.elastic:
        sortingFieldProvider.setSortingField(SortingFields.elasticSignalScore);
        break;
      case _SignalFeedFilter.structure:
        sortingFieldProvider.setSortingField(
          SortingFields.structureSignalScore,
        );
        break;
      case _SignalFeedFilter.all:
        if (sortingFieldProvider.sortingField ==
                SortingFields.setupSignalScore ||
            sortingFieldProvider.sortingField ==
                SortingFields.elasticSignalScore ||
            sortingFieldProvider.sortingField ==
                SortingFields.structureSignalScore) {
          sortingFieldProvider.setSortingField(SortingFields.signalScore);
        }
        break;
    }
  }

  CheckedPopupMenuItem<String> _sortMenuItem({
    required String selectedSort,
    required String value,
    required String label,
  }) {
    return CheckedPopupMenuItem<String>(
      value: value,
      checked: selectedSort == value,
      child: Text(label),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: KSizes.scannerControlHeight,
      decoration: BoxDecoration(
        color: KColors.controlBackground,
        border: Border.all(color: KColors.controlBorder),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: KTextStyles.tokenMetricValue,
        decoration: InputDecoration(
          hintText: 'Search symbol',
          hintStyle: KTextStyles.scannerMeta,
          prefixIcon: const Icon(
            KIcons.search,
            color: KColors.textSecondary,
            size: 20,
          ),
          suffixIcon: IconButton(
            tooltip: _searchQuery.isEmpty ? 'Close search' : 'Clear search',
            onPressed: () {
              if (_searchQuery.isEmpty) {
                setState(() => _isSearchOpen = false);
                return;
              }

              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            icon: const Icon(
              KIcons.clear,
              color: KColors.textSecondary,
              size: 18,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildScannerControls() {
    return Consumer2<TokensProvider, SortingFieldProvider>(
      builder: (context, tokensProvider, sortingFieldProvider, child) {
        final signalCount = _signalCountForFilter(tokensProvider);
        final updatedAt = _formatSignalsUpdatedAt(
          tokensProvider.shortTermBuyCandidatesUpdatedAt,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            KSizes.listViewHorizontalPadding,
            KSpacing.xs,
            KSizes.listViewHorizontalPadding,
            KSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_TokenFeedMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<_TokenFeedMode>(
                          value: _TokenFeedMode.all,
                          label: Text('All'),
                        ),
                        ButtonSegment<_TokenFeedMode>(
                          value: _TokenFeedMode.signals,
                          label: Text('Signals'),
                        ),
                      ],
                      selected: {_feedMode},
                      onSelectionChanged: (selection) {
                        final nextMode = selection.first;
                        setState(() => _feedMode = nextMode);

                        if (nextMode == _TokenFeedMode.signals &&
                            sortingFieldProvider.sortingField ==
                                SortingFields.priceChange) {
                          sortingFieldProvider.setSortingField(
                            SortingFields.signalScore,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () {
                      setState(() => _isSearchOpen = !_isSearchOpen);
                    },
                    icon: Icon(
                      KIcons.search,
                      color: _isSearchOpen
                          ? KColors.activeIcon
                          : KColors.textPrimary,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Sort',
                    icon: const Icon(KIcons.sort, color: KColors.textPrimary),
                    initialValue: sortingFieldProvider.sortingField,
                    onSelected: sortingFieldProvider.setSortingField,
                    itemBuilder: (context) => [
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.priceChange,
                        label: 'Interval change',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.rollingPriceChange5m,
                        label: 'Rolling 5m',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.rollingPriceChange15m,
                        label: 'Rolling 15m',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.rollingPriceChange30m,
                        label: 'Rolling 30m',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.rollingPriceChange1h,
                        label: 'Rolling 1h',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.signalScore,
                        label: 'Best signal',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.setupSignalScore,
                        label: 'Normal signal',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.elasticSignalScore,
                        label: 'Elastic signal',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.structureSignalScore,
                        label: 'Structure signal',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.rsiRebound,
                        label: 'RSI first rebound',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.volume,
                        label: 'Volume',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.relativeVolume5m,
                        label: 'Relative volume',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.ema7Pullback5m,
                        label: 'EMA7 5m pullback',
                      ),
                      _sortMenuItem(
                        selectedSort: sortingFieldProvider.sortingField,
                        value: SortingFields.ema7Pullback30m,
                        label: 'EMA7 30m pullback',
                      ),
                    ],
                  ),
                ],
              ),
              if (_isSearchOpen) ...[
                const SizedBox(height: KSpacing.sm),
                _buildSearchField(),
              ],
              if (_feedMode == _TokenFeedMode.signals) ...[
                const SizedBox(height: KSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_SignalFeedFilter>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<_SignalFeedFilter>(
                        value: _SignalFeedFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment<_SignalFeedFilter>(
                        value: _SignalFeedFilter.setup,
                        label: Text('Normal'),
                      ),
                      ButtonSegment<_SignalFeedFilter>(
                        value: _SignalFeedFilter.elastic,
                        label: Text('Elastic'),
                      ),
                      ButtonSegment<_SignalFeedFilter>(
                        value: _SignalFeedFilter.structure,
                        label: Text('Structure'),
                      ),
                    ],
                    selected: {_signalFilter},
                    onSelectionChanged: (selection) =>
                        _setSignalFilter(selection.first, sortingFieldProvider),
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  '$signalCount ${_signalFilterLabel(_signalFilter)} - updated $updatedAt',
                  style: KTextStyles.scannerMeta,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tradeModeProvider = context.watch<TradeModeProvider>();

    return Scaffold(
      backgroundColor: KColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: KTextStyles.appBarTitle),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: widget.showTradeButtons
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: KSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tradeModeProvider.isDemoMode ? 'Demo' : 'Real',
                        style: KTextStyles.scannerMeta.copyWith(
                          color: tradeModeProvider.isDemoMode
                              ? KColors.accentWarning
                              : KColors.accentNegative,
                        ),
                      ),
                      Switch.adaptive(
                        value: tradeModeProvider.isRealMode,
                        activeThumbColor: KColors.accentNegative,
                        inactiveThumbColor: KColors.accentWarning,
                        onChanged: (isRealMode) {
                          tradeModeProvider.setDemoMode(!isRealMode);
                        },
                      ),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          _buildScannerControls(),
          Expanded(
            child: TokenListViewSection(
              showList: true,
              historicalKlines: _historicalKlines,
              showCharts: widget.showCharts,
              showTradeButtons: widget.showTradeButtons,
              searchQuery: _searchQuery,
              showSignalsOnly: _feedMode == _TokenFeedMode.signals,
              signalFilter: _signalFilterValue(_signalFilter),
              onTokenTap: _openTokenScreen,
              onEma7LimitOcoPressed: _ema7LimitOcoPressed,
              onMarketAutoClosePressed: _marketAutoClosePressed,
              onBuyPressed: _buyPressed,
              onQuickBuyPressed: _quickBuyPressed,
              onSellPressed: _sellPressed,
            ),
          ),
        ],
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
