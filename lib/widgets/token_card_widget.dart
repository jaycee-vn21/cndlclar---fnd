import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cndlclar/utils/constants.dart';
import 'sparkline_widget.dart';
import 'indicator_row_widget.dart';

class TokenCardWidget extends StatelessWidget {
  final String tokenName;
  final double currentPrice;
  final double selectedIntervalChange;
  final double dailyChange;
  final double? volume;
  final double? marketCap;

  final List<double> sparklineData;
  final Map<String, dynamic> indicators;

  const TokenCardWidget({
    super.key,
    required this.tokenName,
    required this.currentPrice,
    required this.selectedIntervalChange,
    required this.dailyChange,
    this.volume,
    this.marketCap,
    required this.sparklineData,
    required this.indicators,
  });

  String _formatLargeNumber(double value) {
    if (value >= 1e12) return "${(value / 1e12).toStringAsFixed(2)}T";
    if (value >= 1e9) return "${(value / 1e9).toStringAsFixed(2)}B";
    if (value >= 1e6) return "${(value / 1e6).toStringAsFixed(2)}M";
    if (value >= 1e3) return "${(value / 1e3).toStringAsFixed(1)}K";
    return value.toStringAsFixed(0);
  }

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

  Widget _buildIndicators() {
    final List<Map<String, dynamic>> indicatorList = indicators.entries.map((
      e,
    ) {
      final key = e.key; // "ema", "rsi", "macd"...
      final valueMap = e.value as Map<String, dynamic>;
      final iconMap = {
        "ema": Icons.trending_up,
        "rsi": Icons.show_chart,
        "macd": Icons.multiline_chart,
        "stoch": Icons.stacked_line_chart,
      };
      return {
        "label": key.toUpperCase(),
        "value": valueMap["value"],
        "icon": iconMap[key] ?? Icons.trending_up,
        "bullish": valueMap["bullish"] ?? true,
      };
    }).toList();

    return IndicatorRowWidget(indicators: indicatorList);
  }

  @override
  Widget build(BuildContext context) {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tokenName, style: KTextStyles.tokenName),
                  Text(
                    "\$${currentPrice.toStringAsFixed(2)}",
                    style: KTextStyles.tokenPrice,
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),

              // --- Indicators ---
              _buildIndicators(),

              // --- Sparkline ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                child: SparklineWidget(data: sparklineData),
              ),
              const SizedBox(height: KSpacing.sm),

              // --- Metrics ---
              _buildMetricRow(
                "Selected Interval",
                "${selectedIntervalChange >= 0 ? '+' : ''}${selectedIntervalChange.toStringAsFixed(2)}%",
                valueColor: selectedIntervalChange >= 0
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
              _buildMetricRow(
                "24h Change",
                "${dailyChange >= 0 ? '+' : ''}${dailyChange.toStringAsFixed(2)}%",
                valueColor: dailyChange >= 0
                    ? KColors.accentPositive
                    : KColors.accentNegative,
              ),
              if (volume != null)
                _buildMetricRow("Volume", _formatLargeNumber(volume!)),
              if (marketCap != null)
                _buildMetricRow("Market Cap", _formatLargeNumber(marketCap!)),
            ],
          ),
        ),
      ),
    );
  }
}
