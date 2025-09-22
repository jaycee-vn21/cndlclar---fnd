import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/utils/constants.dart';
import 'package:cndlclar/widgets/token_card_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> intervals = ['1m', '5m', '15m', '1h', '1d'];
  final Random _random = Random();
  Timer? _timer;

  // Store sparkline & indicator data per token
  late Map<String, List<double>> tokenSparklines;
  late Map<String, Map<String, dynamic>> tokenIndicators;

  @override
  void initState() {
    super.initState();
    tokenSparklines = {};
    tokenIndicators = {};

    // --- Optimized Timer ---
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      final tokensProvider = Provider.of<TokensProvider>(
        context,
        listen: false,
      );
      final tokens = tokensProvider.getTokens();

      // Only update the data maps; no full widget rebuild yet
      for (final token in tokens) {
        // --- Update sparkline ---
        final data = tokenSparklines[token.name] ?? [];
        if (data.isNotEmpty) {
          final last = data.last;
          final newPoint =
              last + (_random.nextDouble() - 0.5) * token.price * 0.01;
          tokenSparklines[token.name] = [...data.skip(1), newPoint];
        }

        // --- Update dummy indicators ---
        tokenIndicators[token.name] = {
          "ema": {
            "value":
                "${(token.price / 1000).toStringAsFixed(1)}/${(token.price / 1050).toStringAsFixed(1)}",
            "bullish": _random.nextBool(),
          },
          "rsi": {
            "value": (30 + _random.nextInt(70)).toString(),
            "bullish": _random.nextBool(),
          },
          "macd": {
            "value": (token.price * 0.0001 * _random.nextDouble())
                .toStringAsFixed(2),
            "bullish": _random.nextBool(),
          },
          "stoch": {
            "value": (10 + _random.nextInt(90)).toString(),
            "bullish": _random.nextBool(),
          },
        };
      }

      // Trigger rebuild **only if mounted**
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Generate initial sparkline
  List<double> generateSparkline(double basePrice) {
    return List.generate(
      20,
      (index) => basePrice + (_random.nextDouble() - 0.5) * basePrice * 0.03,
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Use Consumer for token list only, reducing rebuilds ---
    return Consumer<TokensProvider>(
      builder: (context, tokensProvider, child) {
        final tokens = tokensProvider.getTokens();

        // Initialize sparklines and indicators if not yet created
        for (final token in tokens) {
          tokenSparklines[token.name] ??= generateSparkline(token.price);
          tokenIndicators[token.name] ??= {
            "ema": {"value": "15/14", "bullish": true},
            "rsi": {"value": "72", "bullish": false},
            "macd": {"value": "0.32", "bullish": true},
            "stoch": {"value": "18", "bullish": false},
          };
        }

        return Scaffold(
          backgroundColor: KColors.background,
          appBar: AppBar(
            title: const Text('CndlClar', style: KTextStyles.appBarTitle),
            backgroundColor: Colors.transparent,
            centerTitle: true,
            elevation: 0,
          ),
          body: Column(
            children: [
              // Interval Selector
              _IntervalSelector(intervals: intervals),

              const SizedBox(height: KSpacing.md),

              // Tokens List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSizes.listViewHorizontalPadding,
                    vertical: KSizes.listViewBottomPadding,
                  ),
                  itemCount: tokens.length,
                  itemBuilder: (context, index) {
                    final token = tokens[index];

                    // Wrap TokenCardWidget in ValueListenableBuilder for partial updates
                    return Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.md),
                      child: TokenCardWidget(
                        tokenName: token.name,
                        currentPrice: token.price,
                        selectedIntervalChange: token.changeSelectedInterval,
                        dailyChange: token.change1d,
                        volume: token.volume,
                        marketCap: token.marketCap,
                        sparklineData: tokenSparklines[token.name]!,
                        indicators: tokenIndicators[token.name]!,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IntervalSelector extends StatelessWidget {
  final List<String> intervals;
  const _IntervalSelector({required this.intervals});

  @override
  Widget build(BuildContext context) {
    final tokensProvider = Provider.of<TokensProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: KSizes.intervalButtonVerticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: intervals.map((interval) {
          final isSelected = tokensProvider.selectedInterval == interval;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSizes.intervalButtonSpacing,
            ),
            child: GestureDetector(
              onTap: () => tokensProvider.setSelectedInterval(interval),
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
