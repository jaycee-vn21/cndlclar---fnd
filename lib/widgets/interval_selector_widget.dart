import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/utils/constants.dart';

class IntervalSelectorWidget extends StatelessWidget {
  final List<String> intervals;
  const IntervalSelectorWidget({super.key, required this.intervals});

  @override
  Widget build(BuildContext context) {
    final intervalProvider = Provider.of<IntervalProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: KSizes.intervalButtonVerticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: intervals.map((interval) {
          final isSelected = intervalProvider.selectedInterval == interval;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSizes.intervalButtonSpacing,
            ),
            child: GestureDetector(
              onTap: () => intervalProvider.setInterval(interval),
              child: AnimatedContainer(
                duration: KDurations.fastAnimation,
                constraints: const BoxConstraints(
                  minWidth: KSizes.intervalButtonMinWidth,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: KSizes.intervalButtonHorizontalPadding,
                  vertical: KSizes.intervalButtonVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? KColors.accentPositive
                      : KColors.intervalUnselected,
                  borderRadius: BorderRadius.circular(
                    KSizes.intervalButtonBorderRadius,
                  ),
                ),
                child: Text(
                  interval,
                  style: isSelected
                      ? KTextStyles.intervalSelected
                      : KTextStyles.interval,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
