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
  static const _rsiReboundInterval = '5m';
  static const _rsiReboundWindowCandles = 18;

  final bool showList;
  final Token? singleToken;
  final Map<String, Map<String, List<KlineData>>>? historicalKlines;
  final Function(Token)? onTokenTap;
  final String searchQuery;
  final bool showSignalsOnly;
  final String signalFilter;
  final bool showCharts;
  final bool showTradeButtons;

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
    this.showCharts = true,
    this.showTradeButtons = true,
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
    Map<String, double?> rsiReboundScoresBySymbol = const {},
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
      case SortingFields.structureSignalScore:
        return signal?.structureScore ?? double.negativeInfinity;
      case SortingFields.rsiRebound:
        return rsiReboundScoresBySymbol[token.name] ??
            signal?.metric('rsiReboundScore') ??
            double.negativeInfinity;
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
      case 'structure':
        return signal.hasStructureSignal;
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

  double? _rsiReboundScore(Token token) {
    final candles = historicalKlines?[token.name]?[_rsiReboundInterval];
    if (candles == null || candles.length < 20) return null;

    final closedCandles =
        candles.where((candle) => candle.isClosed).toList(growable: false)
          ..sort((a, b) => a.time.compareTo(b.time));
    if (closedCandles.length < 20) return null;

    final closes = closedCandles
        .map((candle) => candle.close)
        .toList(growable: false);
    final rsi3Values = _rsiSeries(closes, 3);
    final rsi14Values = _rsiSeries(closes, 14);
    final startIndex = math.max(
      14,
      closedCandles.length - _rsiReboundWindowCandles,
    );
    final runs = <_RsiAboveRun>[];
    _RsiAboveRun? currentRun;

    for (var index = startIndex; index < closedCandles.length; index += 1) {
      final rsi3 = rsi3Values[index];
      final rsi14 = rsi14Values[index];
      final isAbove = rsi3 != null && rsi14 != null && rsi3 > rsi14;

      if (isAbove) {
        currentRun ??= _RsiAboveRun(startIndex: index);
        currentRun.update(index: index, rsi3: rsi3);
      } else if (currentRun != null) {
        runs.add(currentRun);
        currentRun = null;
      }
    }

    if (currentRun != null) {
      runs.add(currentRun);
    }

    if (runs.isEmpty) return double.negativeInfinity;

    final run = runs.first;
    final latestCandle = closedCandles.last;
    final peakCandle = closedCandles[run.maxRsi3Index];
    final dropFromPeak = _percentDistance(latestCandle.close, peakCandle.close);
    final latestClosedChange = _percentDistance(
      latestCandle.close,
      latestCandle.open,
    );
    final latestRange = _percentDistance(latestCandle.high, latestCandle.low);
    final previousRanges = closedCandles
        .skip(math.max(0, closedCandles.length - 7))
        .take(math.max(0, math.min(6, closedCandles.length - 1)))
        .map((candle) => _percentDistance(candle.high, candle.low))
        .whereType<double>()
        .where((value) => value > 0)
        .toList(growable: false);
    final averageRange = previousRanges.isEmpty
        ? null
        : previousRanges.reduce((sum, value) => sum + value) /
              previousRanges.length;
    final rangeExpansionRatio =
        latestRange != null && averageRange != null && averageRange > 0
        ? latestRange / averageRange
        : null;
    final currentPriceChange = token.priceChange(_rsiReboundInterval);
    final currentRsi3 = _lastFinite(rsi3Values);
    final currentRsi14 = _lastFinite(rsi14Values);
    final barsSincePeak = closedCandles.length - 1 - run.maxRsi3Index;
    final runEnded = run.endIndex < closedCandles.length - 1;

    var score = 0.0;

    if (runs.length == 1) {
      score += 30;
    } else {
      score -= 90;
    }

    if (run.length >= 5) {
      score += 28;
    } else if (run.length >= 4) {
      score += 20;
    } else {
      score -= 45;
    }

    if (run.maxRsi3 >= 92) {
      score += 24;
    } else if (run.maxRsi3 >= 90) {
      score += 18;
    } else {
      score -= 36;
    }

    if (dropFromPeak != null) {
      if (dropFromPeak <= -0.18 && dropFromPeak >= -2.8) {
        score += 26;
      } else if (dropFromPeak < -2.8 && dropFromPeak >= -4.2) {
        score += 6;
      } else if (dropFromPeak < -4.2) {
        score -= 34;
      } else if (dropFromPeak > 0.25) {
        score -= 18;
      }
    }

    if (currentPriceChange >= -1.4 && currentPriceChange <= 0.2) {
      score += 14;
    } else if (currentPriceChange < -2.2 || currentPriceChange > 2.8) {
      score -= 22;
    }

    if (latestClosedChange != null) {
      if (latestClosedChange <= 0.4 && latestClosedChange >= -1.8) {
        score += 8;
      } else if (latestClosedChange < -2.4 || latestClosedChange > 2.4) {
        score -= 12;
      }
    }

    if (barsSincePeak >= 1 && barsSincePeak <= 8) {
      score += 10;
    } else if (barsSincePeak > 10) {
      score -= 12;
    }

    if (runEnded) {
      score += 12;
    } else if (currentRsi3 != null && currentRsi3 <= run.maxRsi3 - 8) {
      score += 6;
    }

    if (currentRsi3 != null && currentRsi14 != null) {
      if (currentRsi3 <= currentRsi14 + 2) {
        score += 8;
      } else if (currentRsi3 > currentRsi14 && runEnded) {
        score -= 18;
      }
    }

    if (rangeExpansionRatio != null) {
      if (rangeExpansionRatio >= 1.15 && rangeExpansionRatio <= 2.8) {
        score += 8;
      } else if (rangeExpansionRatio > 3.8) {
        score -= 8;
      }
    }

    if (runs.length >= 2) {
      score = math.min(score, -40);
    }
    if (run.length < 4 || run.maxRsi3 < 90) {
      score = math.min(score, 15);
    }

    return score;
  }

  List<double?> _rsiSeries(List<double> prices, int period) {
    if (prices.length <= period) {
      return List<double?>.filled(prices.length, null);
    }

    final values = List<double?>.filled(prices.length, null);
    var gains = 0.0;
    var losses = 0.0;

    for (var index = 1; index <= period; index += 1) {
      final change = prices[index] - prices[index - 1];
      if (change > 0) {
        gains += change;
      } else {
        losses += change.abs();
      }
    }

    var averageGain = gains / period;
    var averageLoss = losses / period;
    values[period] = averageLoss == 0
        ? 100
        : 100 - 100 / (1 + averageGain / averageLoss);

    for (var index = period + 1; index < prices.length; index += 1) {
      final change = prices[index] - prices[index - 1];
      if (change > 0) {
        averageGain = (averageGain * (period - 1) + change) / period;
        averageLoss = (averageLoss * (period - 1)) / period;
      } else if (change < 0) {
        averageGain = (averageGain * (period - 1)) / period;
        averageLoss = (averageLoss * (period - 1) + change.abs()) / period;
      } else {
        averageGain = (averageGain * (period - 1)) / period;
        averageLoss = (averageLoss * (period - 1)) / period;
      }

      values[index] = averageLoss == 0
          ? 100
          : 100 - 100 / (1 + averageGain / averageLoss);
    }

    return values;
  }

  double? _percentDistance(double firstValue, double secondValue) {
    if (secondValue == 0) return null;
    final value = ((firstValue - secondValue) / secondValue) * 100;
    return value.isFinite ? value : null;
  }

  double? _lastFinite(List<double?> values) {
    for (var index = values.length - 1; index >= 0; index -= 1) {
      final value = values[index];
      if (value != null && value.isFinite) return value;
    }
    return null;
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
        final rsiReboundScoresBySymbol = sortField == SortingFields.rsiRebound
            ? {
                for (final token in rawTokens)
                  token.name: _rsiReboundScore(token),
              }
            : const <String, double?>{};

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
                rsiReboundScoresBySymbol: rsiReboundScoresBySymbol,
              );
              final bValue = _sortValue(
                token: b,
                sortField: sortField,
                selectedInterval: selectedInterval,
                tokensProvider: tokensProvider,
                rsiReboundScoresBySymbol: rsiReboundScoresBySymbol,
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
                                : signalFilter == 'structure'
                                ? 'No structure signals yet'
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
                              showChart: showCharts,
                              showTradeButtons: showTradeButtons,
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

class _RsiAboveRun {
  _RsiAboveRun({required this.startIndex})
    : endIndex = startIndex,
      length = 0,
      maxRsi3 = double.negativeInfinity,
      maxRsi3Index = startIndex;

  final int startIndex;
  int endIndex;
  int length;
  double maxRsi3;
  int maxRsi3Index;

  void update({required int index, required double rsi3}) {
    endIndex = index;
    length += 1;

    if (rsi3 > maxRsi3) {
      maxRsi3 = rsi3;
      maxRsi3Index = index;
    }
  }
}
