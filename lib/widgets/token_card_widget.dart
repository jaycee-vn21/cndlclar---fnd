import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/indicator.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/widgets/indicator_row_widget.dart';
import 'package:cndlclar/widgets/sparkline_widget.dart';
import 'package:cndlclar/utils/constants.dart';

class TokenCardWidget extends StatelessWidget {
  final String tokenName;
  final double currentPrice;
  final double selectedIntervalChange;
  final double dailyChange;
  final double? volume;
  final double? marketCap;

  final List<double> sparklineData;
  final List<Indicator> indicators; // fully typed model

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
                    "\$${currentPrice.toStringAsFixed(5)}",
                    style: KTextStyles.tokenPrice,
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),

              // --- Indicators (uses Indicator model directly) ---
              IndicatorRowWidget(indicators: indicators),

              // --- Sparkline chart ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                child: SparklineWidget(data: sparklineData),
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
            ],
          ),
        ),
      ),
    );
  }
}
