import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/utils/constants.dart';

class IntervalCountdownWidget extends StatefulWidget {
  const IntervalCountdownWidget({super.key});

  @override
  State<IntervalCountdownWidget> createState() =>
      _IntervalCountdownWidgetState();
}

class _IntervalCountdownWidgetState extends State<IntervalCountdownWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Duration _remaining = Duration.zero;
  Duration _total = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Initialize glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Initialize immediately
    _updateRemaining();

    // Update every second
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final intervalProvider = Provider.of<IntervalProvider>(
      context,
      listen: false,
    );
    final tokensProvider = Provider.of<TokensProvider>(context, listen: false);

    final selectedInterval = intervalProvider.selectedInterval;
    final tokens = tokensProvider.tokens;
    if (tokens.isEmpty) return;

    final startTime = tokens.first.startTime(selectedInterval);
    if (startTime == null) return;

    final durationValue =
        int.tryParse(selectedInterval.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    if (selectedInterval.contains('d')) {
      _total = Duration(days: durationValue);
    } else if (selectedInterval.contains('h')) {
      _total = Duration(hours: durationValue);
    } else {
      _total = Duration(minutes: durationValue);
    }

    final now = DateTime.now();
    Duration remaining = startTime.add(_total).difference(now);

    if (remaining.isNegative) {
      intervalProvider.updateIntervalStartTime(selectedInterval, now);
      remaining = _total;
    }

    setState(() {
      _remaining = remaining;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intervalProvider = Provider.of<IntervalProvider>(context);
    final selectedInterval = intervalProvider.selectedInterval;

    final progress =
        1 - (_remaining.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    String timeString;
    if (selectedInterval.contains('d')) {
      timeString =
          "${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else if (selectedInterval.contains('h')) {
      timeString =
          "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      timeString =
          "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSizes.listViewHorizontalPadding,
            vertical: KSpacing.xs,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              KSizes.countdownProgressBorderRadius,
            ),
            child: Stack(
              children: [
                // Background
                Container(
                  height: KSizes.countdownProgressHeight,
                  color: KColors.progressBackground,
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth * progress;

                    return AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        final glowX = width * _glowController.value;

                        return Stack(
                          children: [
                            // Gradient fill
                            Container(
                              width: width,
                              height: KSizes.countdownProgressHeight,
                              decoration: KDecorations.countdownBackground,
                            ),
                            // Glow highlight
                            Positioned(
                              left: glowX - KSizes.countdownGlowWidth / 2,
                              child: Container(
                                width: KSizes.countdownGlowWidth,
                                height: KSizes.countdownGlowHeight,
                                decoration: KDecorations.countdownForeground,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: KSpacing.xs),
          child: Text(
            "$selectedInterval candle renews in $timeString",
            style: KTextStyles.intervalCountdown,
          ),
        ),
      ],
    );
  }
}
