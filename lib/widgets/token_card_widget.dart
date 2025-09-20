import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cndlclar/utils/constants.dart';
import 'sparkline_widget.dart';

class TokenCardWidget extends StatelessWidget {
  final String tokenName;
  final double currentPrice;
  final double selectedIntervalChange;
  final double dailyChange;
  final double? volume;
  final double? marketCap;

  final List<double>? sparklineData;

  const TokenCardWidget({
    super.key,
    required this.tokenName,
    required this.currentPrice,
    required this.selectedIntervalChange,
    required this.dailyChange,
    this.volume,
    this.marketCap,
    this.sparklineData,
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KSizes.tokenCardBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: KSizes.tokenCardBlurSigma,
          sigmaY: KSizes.tokenCardBlurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.all(KSizes.tokenCardPadding),
          decoration: BoxDecoration(
            gradient: KGradients.tokenCard,
            color: KColors.cardBackground.withOpacity(
              KSizes.tokenCardBackgroundOpacity,
            ),
            borderRadius: BorderRadius.circular(KSizes.tokenCardBorderRadius),
            boxShadow: [KShadows.tokenCard],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Price
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

              // Sparkline
              if (sparklineData != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: KSizes.tokenSparklineVerticalSpacing,
                  ),
                  child: SparklineWidget(data: sparklineData!),
                ),

              const SizedBox(height: KSpacing.sm),

              // Metrics
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
