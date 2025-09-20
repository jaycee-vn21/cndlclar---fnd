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
  late Map<String, List<double>> tokenSparklines;

  @override
  void initState() {
    super.initState();
    tokenSparklines = {};

    // Timer to simulate live sparkline updates
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      final tokensProvider = Provider.of<TokensProvider>(
        context,
        listen: false,
      );
      final tokens = tokensProvider.getTokens();

      setState(() {
        for (final token in tokens) {
          final data = tokenSparklines[token.name] ?? [];
          if (data.isEmpty) continue;

          final last = data.last;
          final newPoint =
              last + (_random.nextDouble() - 0.5) * token.price * 0.01;
          tokenSparklines[token.name] = [...data.skip(1), newPoint];
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Generate initial unique sparkline for each token
  List<double> generateSparkline(double basePrice) {
    return List.generate(
      20,
      (index) => basePrice + (_random.nextDouble() - 0.5) * basePrice * 0.03,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokensProvider = Provider.of<TokensProvider>(context);
    final tokens = tokensProvider.getTokens();

    for (final token in tokens) {
      tokenSparklines[token.name] ??= generateSparkline(token.price);
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
          Padding(
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
          ),

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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
