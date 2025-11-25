import 'package:flutter/material.dart';
import 'package:cndlclar/models/indicator.dart';
import 'package:cndlclar/utils/constants.dart';

/// Displays a horizontal row of indicators for a token.
/// Fully typed: uses [Indicator] model directly.
class IndicatorRowWidget extends StatelessWidget {
  final List<Indicator>? indicators;

  const IndicatorRowWidget({super.key, this.indicators});

  /// Builds a single indicator widget: label, value, icon
  Widget _buildIndicator(Indicator indicator) {
    // Try parsing numeric value for consistent formatting
    final numericValue = double.tryParse(indicator.value);
    final displayValue = numericValue != null
        ? numericValue.toStringAsFixed(2)
        : indicator.value;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(indicator.label, style: KTextStyles.indicatorLabel),
        const SizedBox(width: KSpacing.xs),
        Text(displayValue, style: KTextStyles.indicatorValue),
        const SizedBox(width: KSpacing.xxs),
        Icon(
          indicator.icon,
          size: KSizes.indicatorIconSize,
          color: indicator.bullish
              ? KColors.accentPositive
              : KColors.accentNegative,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (indicators == null || indicators!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Wrap(
        spacing: KSpacing.md,
        runSpacing: KSpacing.xs,
        children: indicators!.map(_buildIndicator).toList(),
      ),
    );
  }
}
