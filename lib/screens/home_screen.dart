import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/widgets/interval_selector_widget.dart';
import 'package:cndlclar/widgets/token_card_widget.dart';
import 'package:cndlclar/utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // -----------------------------
    // Dummy data updater (optional)
    // Remove or disable in production when using real backend
    // -----------------------------
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      final tokensProvider = Provider.of<TokensProvider>(
        context,
        listen: false,
      );
      tokensProvider.updateDummyData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TokensProvider>(
      builder: (context, tokensProvider, child) {
        final tokens = tokensProvider.getTokens();

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
              // -----------------------------
              // Interval Selector
              // -----------------------------
              IntervalSelectorWidget(
                intervals: const ['1m', '5m', '15m', '1h', '1d'],
              ),

              const SizedBox(height: KSpacing.md),

              // -----------------------------
              // Tokens List
              // -----------------------------
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

                    // TokenCardWidget
                    return Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.md),
                      child: TokenCardWidget(
                        tokenName: token.name,
                        currentPrice: token.price,
                        selectedIntervalChange: token.changeSelectedInterval,
                        dailyChange: token.change1d,
                        volume: token.volume,
                        marketCap: token.marketCap,
                        sparklineData:
                            tokensProvider.tokenSparklines[token.name] ?? [],
                        indicators: token.indicators,
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
