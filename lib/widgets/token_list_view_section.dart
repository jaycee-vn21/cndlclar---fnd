import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/providers/sorting_field_provider.dart';
import 'package:cndlclar/widgets/interval_selector_widget.dart';
import 'package:cndlclar/widgets/interval_countdown_widget.dart';
import 'package:cndlclar/widgets/token_card_widget.dart';
import 'package:cndlclar/utils/constants.dart';

class TokenListViewSection extends StatelessWidget {
  static const _rollingRankIntervals = ['5m', '15m', '30m', '1h'];

  final bool showList;
  final Token? singleToken;
  final Map<String, Map<String, List<KlineData>>>? historicalKlines;
  final Function(Token)? onTokenTap;
  final String searchQuery;
  final bool showSignalsOnly;
  final String signalFilter;

  // trade button handlers
  final Function(Token)? onEma7LimitOcoPressed;
  final Function(Token)? onMarketAutoClosePressed;
  final Function(Token)? onBuyPressed;
  final Function(Token)? onQuickBuyPressed;
  final Function(Token)? onSellPressed;

  const TokenListViewSection({
    super.key,
    this.showList = true,
    this.singleToken,
    this.historicalKlines,
    this.onTokenTap,
    this.searchQuery = '',
    this.showSignalsOnly = false,
    this.signalFilter = 'all',
    this.onEma7LimitOcoPressed,
    this.onMarketAutoClosePressed,
    this.onBuyPressed,
    this.onQuickBuyPressed,
    this.onSellPressed,
  });

  bool _matchesSearch(Token token) {
    final normalizedQuery = searchQuery
        .trim()
        .toUpperCase()
        .replaceAll('/', '')
        .replaceAll(' ', '');

    if (normalizedQuery.isEmpty) return true;

    final symbol = token.name.toUpperCase();
    final baseSymbol = symbol.endsWith('USDT')
        ? symbol.substring(0, symbol.length - 4)
        : symbol;

    return symbol.contains(normalizedQuery) ||
        baseSymbol.contains(normalizedQuery);
  }

  double _sortValue({
    required Token token,
    required String sortField,
    required String selectedInterval,
    required TokensProvider tokensProvider,
  }) {
    final signal = tokensProvider.shortTermBuyCandidatesBySymbol[token.name];

    switch (sortField) {
      case SortingFields.tickerPriceChange1h:
      case SortingFields.rollingPriceChange1h:
        return token.tickerPriceChange1h;
      case SortingFields.rollingPriceChange5m:
        return token.hasRollingPriceChange('5m')
            ? token.rollingPriceChange('5m')
            : double.negativeInfinity;
      case SortingFields.rollingPriceChange15m:
        return token.hasRollingPriceChange('15m')
            ? token.rollingPriceChange('15m')
            : double.negativeInfinity;
      case SortingFields.rollingPriceChange30m:
        return token.hasRollingPriceChange('30m')
            ? token.rollingPriceChange('30m')
            : double.negativeInfinity;
      case SortingFields.signalScore:
        return signal?.score ?? double.negativeInfinity;
      case SortingFields.setupSignalScore:
        return signal?.setupScore ?? double.negativeInfinity;
      case SortingFields.elasticSignalScore:
        return signal?.elasticScore ?? double.negativeInfinity;
      case SortingFields.volume:
        return token.volume(selectedInterval);
      case SortingFields.relativeVolume5m:
        return signal?.metric('relativeVolume5m') ?? 0;
      case SortingFields.ema7Setup:
        return _ema7SetupScore(token, selectedInterval) ??
            signal?.metric('ema7SetupScore5m') ??
            double.negativeInfinity;
      case SortingFields.priceChange:
      default:
        return token.priceChange(selectedInterval);
    }
  }

  bool _matchesSignalFilter(Token token, TokensProvider tokensProvider) {
    if (!showSignalsOnly) return true;

    final signal = tokensProvider.shortTermBuyCandidatesBySymbol[token.name];
    if (signal == null) return false;

    switch (signalFilter) {
      case 'setup':
        return signal.hasSetupSignal;
      case 'elastic':
        return signal.hasElasticSignal;
      case 'all':
      default:
        return true;
    }
  }

  double? _ema7SetupScore(Token token, String selectedInterval) {
    final candles = historicalKlines?[token.name]?[selectedInterval];
    if (candles == null || candles.length < 8) return null;

    final sortedCandles = List<KlineData>.from(candles)
      ..sort((a, b) => a.time.compareTo(b.time));
    final latest = sortedCandles.last;
    final ema7 = _emaValue(
      sortedCandles.map((candle) => candle.close).toList(growable: false),
      7,
    );
    if (ema7 == null || ema7 <= 0) return null;

    final closeDistance = ((latest.close - ema7) / ema7) * 100;
    final lowDistance = ((latest.low - ema7) / ema7) * 100;
    final touchedEma7 = lowDistance <= 0.18 && lowDistance >= -0.45;
    final closedAboveEma7 = closeDistance >= 0;

    var score = 100.0;
    score -= lowDistance.abs() * 36;
    score -= math.max(closeDistance - 1.15, 0) * 24;
    score -= math.max(-closeDistance - 0.2, 0) * 45;

    if (touchedEma7 && closedAboveEma7) score += 30;
    if (closedAboveEma7) score += 12;

    return score;
  }

  double? _emaValue(List<double> prices, int period) {
    if (prices.length < period) return null;

    final smoothing = 2 / (period + 1);
    var ema = prices.take(period).reduce((sum, price) => sum + price) / period;

    for (var i = period; i < prices.length; i++) {
      ema = prices[i] * smoothing + ema * (1 - smoothing);
    }

    return ema;
  }

  Map<String, Map<String, int>> _rollingPriceChangeRanks(
    List<Token> rankTokens,
  ) {
    final ranksBySymbol = <String, Map<String, int>>{};

    for (final interval in _rollingRankIntervals) {
      final rankedTokens =
          rankTokens
              .where((token) => token.hasRollingPriceChange(interval))
              .toList(growable: false)
            ..sort(
              (a, b) => b
                  .rollingPriceChange(interval)
                  .compareTo(a.rollingPriceChange(interval)),
            );

      double? previousValue;
      var displayedRank = 0;

      for (var index = 0; index < rankedTokens.length; index += 1) {
        final token = rankedTokens[index];
        final value = token.rollingPriceChange(interval);

        if (previousValue == null || value != previousValue) {
          displayedRank = index + 1;
          previousValue = value;
        }

        ranksBySymbol.putIfAbsent(token.name, () => <String, int>{})[interval] =
            displayedRank;
      }
    }

    return ranksBySymbol;
  }

  Widget _buildEmptyState(String title, {String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showSignalsOnly ? KIcons.signal : KIcons.search,
              color: KColors.textSecondary,
              size: 34,
            ),
            const SizedBox(height: KSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KTextStyles.emptyStateTitle,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: KSpacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: KTextStyles.emptyStateSubtitle,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TokensProvider, IntervalProvider, SortingFieldProvider>(
      builder: (context, tokensProvider, intervalProvider, sortingFieldProvider, child) {
        final selectedInterval = intervalProvider.selectedInterval;
        final sortField = sortingFieldProvider.sortingField;
        final signalBySymbol = tokensProvider.shortTermBuyCandidatesBySymbol;
        final hasSearchQuery = searchQuery.trim().isNotEmpty;
        final rawTokens = showList
            ? List<Token>.from(tokensProvider.tokens)
            : <Token>[
                tokensProvider.tokens.firstWhere(
                  (t) => t.name == singleToken?.name,
                  orElse: () => singleToken!,
                ),
              ];
        final rankTokens = tokensProvider.tokens.isNotEmpty
            ? tokensProvider.tokens
            : rawTokens;
        final rollingRanksBySymbol = _rollingPriceChangeRanks(rankTokens);

        final tokens =
            rawTokens.where((token) {
              if (showList && !_matchesSignalFilter(token, tokensProvider)) {
                return false;
              }

              return !showList || _matchesSearch(token);
            }).toList()..sort((a, b) {
              final aValue = _sortValue(
                token: a,
                sortField: sortField,
                selectedInterval: selectedInterval,
                tokensProvider: tokensProvider,
              );
              final bValue = _sortValue(
                token: b,
                sortField: sortField,
                selectedInterval: selectedInterval,
                tokensProvider: tokensProvider,
              );

              return bValue.compareTo(aValue);
            });

        return Column(
          children: [
            // Interval Selector
            IntervalSelectorWidget(
              intervals: const ['5m', '15m', '30m', '1h', '1d'],
            ),

            // Interval Countdown
            const IntervalCountdownWidget(),

            const SizedBox(height: KSpacing.md),

            // Tokens List or Single Token
            Expanded(
              child: tokensProvider.isConnected && rawTokens.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : tokens.isEmpty
                  ? _buildEmptyState(
                      hasSearchQuery
                          ? 'No matches found'
                          : showSignalsOnly
                          ? signalFilter == 'elastic'
                                ? 'No elastic signals yet'
                                : signalFilter == 'setup'
                                ? 'No normal signals yet'
                                : 'No signal candidates yet'
                          : 'Waiting for market data',
                      subtitle: hasSearchQuery
                          ? 'Try another symbol or switch back to All.'
                          : showSignalsOnly
                          ? 'The backend scanner will fill this view when a setup or elastic signal clears its threshold.'
                          : 'The feed will appear after the backend sends live klines.',
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSizes.listViewHorizontalPadding,
                        vertical: KSizes.listViewBottomPadding,
                      ),
                      itemCount: tokens.length,
                      itemBuilder: (context, index) {
                        final token = tokens[index];
                        return InkWell(
                          key: ValueKey(token.name),
                          onTap: onTokenTap != null
                              ? () => onTokenTap!(token)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: KSpacing.md),
                            child: TokenCardWidget(
                              tokenName: token.name,
                              currentPrice: token.closePrice(selectedInterval),
                              selectedIntervalChange: token.priceChange(
                                selectedInterval,
                              ),
                              tickerPriceChange1h: token.tickerPriceChange1h,
                              rollingPriceChanges:
                                  token.rollingPriceChangePerInterval,
                              rollingPriceChangeReady:
                                  token.rollingPriceChangeReadyPerInterval,
                              rollingPriceChangeRanks:
                                  rollingRanksBySymbol[token.name],
                              allowChartPanAndZoom: !showList,
                              dailyChange: token.priceChange('1d'),
                              // volume: token.volume(selectedInterval),
                              // netVolume: token.netVolume(selectedInterval),
                              // marketCap: token.marketCap,
                              // sparklineData: token.sparkline(
                              //   selectedInterval,
                              // ),
                              // indicators: token.indicators,
                              historicalKlines: historicalKlines,
                              signalCandidate: signalBySymbol[token.name],
                              showSignalDetails: showSignalsOnly,
                              onEma7LimitOcoPressed: () =>
                                  onEma7LimitOcoPressed?.call(token),
                              onMarketAutoClosePressed: () =>
                                  onMarketAutoClosePressed?.call(token),
                              onBuyPressed: () => onBuyPressed?.call(token),
                              onQuickBuyPressed: () =>
                                  onQuickBuyPressed?.call(token),
                              onSellPressed: () => onSellPressed?.call(token),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
