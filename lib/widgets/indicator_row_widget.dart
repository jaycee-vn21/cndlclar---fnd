import 'package:flutter/material.dart';
import '../utils/constants.dart';

class IndicatorRowWidget extends StatelessWidget {
  /// Each indicator map:
  /// { "label": String, "value": num/String, "icon": IconData, "bullish": bool }
  final List<Map<String, dynamic>> indicators;

  const IndicatorRowWidget({super.key, required this.indicators});

  Widget _buildIndicator(Map<String, dynamic> indicator) {
    final label = indicator['label'] as String;
    final rawValue = indicator['value'];
    final value = rawValue is num
        ? rawValue.toStringAsFixed(2)
        : rawValue.toString();
    final icon = indicator['icon'] as IconData;
    final bullish = indicator['bullish'] as bool;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: KTextStyles.indicatorLabel),
        const SizedBox(width: KSpacing.xs),
        Text(value, style: KTextStyles.indicatorValue),
        const SizedBox(width: KSpacing.xxs),
        Icon(
          icon,
          size: KSizes.indicatorIconSize,
          color: bullish ? KColors.accentPositive : KColors.accentNegative,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (indicators.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Wrap(
        spacing: KSpacing.md,
        runSpacing: KSpacing.xs,
        children: indicators.map(_buildIndicator).toList(),
      ),
    );
  }
}
