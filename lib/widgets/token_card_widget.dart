import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/models/indicator.dart';
import 'package:cndlclar/models/short_term_buy_candidate.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/widgets/indicator_row_widget.dart';
// import 'package:cndlclar/widgets/sparkline_widget.dart';
import 'package:cndlclar/widgets/candlestick_chart_widget.dart';
import 'package:cndlclar/widgets/trading_buttons_row_widget.dart';
import 'package:cndlclar/utils/config.dart';
import 'package:cndlclar/utils/constants.dart';

class TokenCardWidget extends StatelessWidget {
  final String tokenName;
  final double currentPrice;
  final double selectedIntervalChange;
  final double dailyChange;
  final double? tickerPriceChange1h;
  final double? volume;
  final double? netVolume;
  final double? marketCap;

  final List<double>? sparklineData;
  final List<Indicator>? indicators;
  final Map<String, Map<String, List<KlineData>>>? historicalKlines;
  final ShortTermBuyCandidate? signalCandidate;
  final bool showSignalDetails;

  // trade button presses
  final VoidCallback onBuyPressed;
  final VoidCallback onQuickBuyPressed;
  final VoidCallback onSellPressed;

  const TokenCardWidget({
    super.key,
    required this.tokenName,
    required this.currentPrice,
    required this.selectedIntervalChange,
    required this.dailyChange,

    this.tickerPriceChange1h,
    this.volume,
    this.netVolume,
    this.marketCap,
    this.sparklineData,
    this.indicators,
    this.historicalKlines,
    this.signalCandidate,
    this.showSignalDetails = false,

    // trade button presses
    required this.onBuyPressed,
    required this.onQuickBuyPressed,
    required this.onSellPressed,
  });

  // -----------------------------
  // Format large numbers like 1.2M, 5B, etc.
  // -----------------------------
  String _formatLargeNumber(double value) {
    if (value >= 1e12) return "${(value / 1e12).toStringAsFixed(2)}T";
    if (value >= 1e9) return "${(value / 1e9).toStringAsFixed(2)}B";
    if (value >= 1e6) return "${(value / 1e6).toStringAsFixed(2)}M";
    if (value >= 1e3) return "${(value / 1e3).toStringAsFixed(1)}K";
    return value.toStringAsFixed(0);
  }

  String _formatPrice(double value) {
    final absoluteValue = value.abs();
    if (absoluteValue >= 1) return value.toStringAsFixed(2);
    if (absoluteValue >= 0.01) return value.toStringAsFixed(4);
    if (absoluteValue >= 0.0001) return value.toStringAsFixed(6);
    return value.toStringAsFixed(8);
  }

  String _formatOptionalPercent(double? value) {
    if (value == null) return 'n/a';
    return "${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%";
  }

  Color _signalColor(double score) {
    if (score >= 55) return KColors.accentPositive;
    if (score >= 35) return KColors.accentWarning;
    return KColors.textSecondary;
  }

  Widget _buildSignalBadge(ShortTermBuyCandidate candidate) {
    final color = _signalColor(candidate.score);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(KIcons.signal, color: color, size: 14),
          const SizedBox(width: KSpacing.xs),
          Text(
            '#${candidate.rank} ${candidate.score.toStringAsFixed(0)}',
            style: KTextStyles.signalScore.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalMetric(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: KColors.controlBackground.withValues(alpha: 0.62),
          border: Border.all(color: KColors.controlBorder),
          borderRadius: BorderRadius.circular(
            KSizes.scannerControlBorderRadius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: KTextStyles.tokenMetricLabel),
            const SizedBox(height: KSpacing.xxs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KTextStyles.tokenMetricValue.copyWith(
                color: color ?? KColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalDetails(ShortTermBuyCandidate candidate) {
    final fiveMinuteChange = candidate.metric('priceChange5m');
    final relativeVolume = candidate.metric('relativeVolume5m');
    final rsi3 = candidate.metric('rsi3in5m');
    final rsi14 = candidate.metric('rsi14in5m');
    final rsi50 = candidate.metric('rsi50in5m');
    final sarDistance = candidate.metric('sarDistance5m');
    final sarTrendUp = candidate.metric('sarTrendUp5m') == 1;
    final ema7Distance = candidate.metric('closeMinusEma7in5m');
    final upperRoom = candidate.metric('bollUpperRoom5m');
    final topReasons = candidate.reasons.take(5).toList(growable: false);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: KSpacing.sm, bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.controlBackground.withValues(alpha: 0.55),
        border: Border.all(color: KColors.controlBorder),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSignalMetric(
                '5m',
                _formatOptionalPercent(fiveMinuteChange),
                color: (fiveMinuteChange ?? 0) >= 0
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
              const SizedBox(width: KSpacing.sm),
              _buildSignalMetric(
                'RelVol',
                relativeVolume == null
                    ? 'n/a'
                    : '${relativeVolume.toStringAsFixed(1)}x',
              ),
              const SizedBox(width: KSpacing.sm),
              _buildSignalMetric(
                'RSI 3',
                rsi3 == null ? 'n/a' : rsi3.toStringAsFixed(0),
                color: (rsi3 ?? 0) >= 50
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
              const SizedBox(width: KSpacing.sm),
              _buildSignalMetric(
                'RSI 14',
                rsi14 == null ? 'n/a' : rsi14.toStringAsFixed(0),
                color: (rsi14 ?? 0) >= 50
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              _buildSignalMetric(
                'RSI 50',
                rsi50 == null ? 'n/a' : rsi50.toStringAsFixed(0),
                color: (rsi50 ?? 0) >= 50
                    ? KColors.accentPositive
                    : KColors.textPrimary,
              ),
              const SizedBox(width: KSpacing.sm),
              _buildSignalMetric(
                'SAR',
                sarDistance == null
                    ? 'n/a'
                    : '${sarTrendUp ? 'UP' : 'DOWN'} ${sarDistance.toStringAsFixed(2)}%',
                color: sarTrendUp
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
              const SizedBox(width: KSpacing.sm),
              _buildSignalMetric(
                'EMA7',
                ema7Distance == null
                    ? 'n/a'
                    : '${ema7Distance.toStringAsFixed(2)}%',
                color: (ema7Distance ?? 0) >= 0 && (ema7Distance ?? 0) <= 2.2
                    ? KColors.accentPositive
                    : KColors.accentWarning,
              ),
              const SizedBox(width: KSpacing.sm),
              _buildSignalMetric(
                'Room',
                upperRoom == null ? 'n/a' : '${upperRoom.toStringAsFixed(2)}%',
              ),
            ],
          ),
          if (topReasons.isNotEmpty) ...[
            const SizedBox(height: KSpacing.md),
            ...topReasons.map((reason) {
              final isNegative = reason.trimLeft().startsWith('-');
              return Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isNegative
                            ? KColors.accentNegative
                            : KColors.accentPositive,
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KTextStyles.scannerMeta.copyWith(
                          color: KColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // -----------------------------
  // Build a single metric row (Selected Interval, 24h change, etc.)
  // -----------------------------
  Widget _buildMetricRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: KSizes.tokenMetricVerticalSpacing / 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTextStyles.tokenMetricLabel),
          SizedBox(
            width: KSizes.tokenMetricMinWidth,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: KTextStyles.tokenMetricValue.copyWith(
                color: valueColor ?? KColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedInterval = Provider.of<IntervalProvider>(
      context,
    ).selectedInterval;

    // Temporary dummy device token
    const String deviceToken = 'abc123-xyz789-2025';

    return ClipRRect(
      borderRadius: BorderRadius.circular(KSizes.tokenCardBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: KEffects.tokenCardBlurSigma,
          sigmaY: KEffects.tokenCardBlurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.all(KSizes.tokenCardPadding),
          decoration: BoxDecoration(
            gradient: KGradients.tokenCard,
            color: KColors.cardBackground.withValues(
              alpha: KEffects.tokenCardBackgroundOpacity,
            ),
            borderRadius: BorderRadius.circular(KSizes.tokenCardBorderRadius),
            boxShadow: [KShadows.tokenCard],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Row 1: Token Name + Price ---
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tokenName.replaceAll('USDT', '/USDT'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KTextStyles.tokenName,
                    ),
                  ),
                  if (signalCandidate != null) ...[
                    const SizedBox(width: KSpacing.sm),
                    _buildSignalBadge(signalCandidate!),
                  ],
                  const SizedBox(width: KSpacing.sm),
                  Text(
                    "\$${_formatPrice(currentPrice)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.tokenPrice,
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),

              if (showSignalDetails && signalCandidate != null)
                _buildSignalDetails(signalCandidate!),

              // --- Indicators ---
              IndicatorRowWidget(indicators: indicators),

              // --- Chart ---
              if (historicalKlines?[tokenName]?[selectedInterval] != null &&
                  historicalKlines!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                  child: SizedBox(
                    height: 250, // small chart height for token card
                    child: CandlestickChartWidget(
                      symbol: tokenName,
                      candles:
                          historicalKlines![tokenName]?[selectedInterval] ?? [],
                    ),
                  ),
                ),
              const SizedBox(height: KSpacing.sm),

              // --- Metrics ---
              if (selectedInterval != '1d')
                _buildMetricRow(
                  "$selectedInterval Candle Change",
                  "${selectedIntervalChange >= 0 ? '+' : ''}${selectedIntervalChange.toStringAsFixed(2)}%",
                  valueColor: selectedIntervalChange >= 0
                      ? KColors.accentPositive
                      : KColors.accentNegative,
                ),
              if (tickerPriceChange1h != null)
                _buildMetricRow(
                  "Ticker 1h Change",
                  "${tickerPriceChange1h! >= 0 ? '+' : ''}${tickerPriceChange1h!.toStringAsFixed(2)}%",
                  valueColor: tickerPriceChange1h! >= 0
                      ? KColors.accentPositive
                      : KColors.accentNegative,
                ),
              _buildMetricRow(
                "1d Candle Change",
                "${dailyChange >= 0 ? '+' : ''}${dailyChange.toStringAsFixed(2)}%",
                valueColor: dailyChange >= 0
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
              if (marketCap != null)
                _buildMetricRow(
                  "Market Cap",
                  '\$${_formatLargeNumber(marketCap!)}',
                ),
              if (volume != null)
                _buildMetricRow(
                  "$selectedInterval Candle VolumeUSDT",
                  '\$${_formatLargeNumber(volume!)}',
                ),
              if (netVolume != null)
                _buildMetricRow(
                  "$selectedInterval Candle NetVolumeUSDT",
                  '\$${_formatLargeNumber(netVolume!)}',
                ),
              if (deviceToken == AppConfig.deviceToken)
                TradingButtonsRowWidget(
                  tokenName: tokenName,
                  onBuy: onBuyPressed,
                  onQuickBuy: onQuickBuyPressed,
                  onSell: onSellPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
