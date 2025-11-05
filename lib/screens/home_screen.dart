import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cndlclar/services/trade_service.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/providers/test_trade_action_provider.dart';
import 'package:cndlclar/widgets/interval_selector_widget.dart';
import 'package:cndlclar/widgets/interval_countdown_widget.dart';
import 'package:cndlclar/widgets/token_card_widget.dart';
import 'package:cndlclar/utils/constants.dart';
import 'package:cndlclar/utils/config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  final TradeService _tradeService = TradeService();

  Future<void> _handleTrade({
    required String action, // "buy" or "sell"
    required String symbol,
    int? requestedLeverage,
    double? priceToBuy,
    double? stopLossPercent,
    double? takeProfitPercent,
    double? baseAmount,
  }) async {
    final result = await _tradeService.executeTrade(
      action: action,
      symbol: symbol,
      requestedLeverage: requestedLeverage,
      priceToBuy: priceToBuy,
      stopLossPercent: stopLossPercent,
      takeProfitPercent: takeProfitPercent,
      baseAmount: baseAmount,
    );

    if (result['success'] == true) {
      final data = result['data'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${action.toUpperCase()} Successful ✅: ${data['message'] ?? ''}',
            style: TextStyle(color: KColors.textPrimary),
          ),
          backgroundColor: KColors.tradeSuccessfulSnackbar,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trade Failed ❌: ${result['error']}',
            style: TextStyle(color: KColors.textPrimary),
          ),
          backgroundColor: KColors.tradeFailedSnackbar,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // connect to backend
    final tokensProvider = Provider.of<TokensProvider>(context, listen: false);
    tokensProvider.connectToBackend(AppConfig.baseUrl);

    // Keep sparklines alive (dummy updates)
    _timer = Timer.periodic(KDurations.dummySparklineAnimation, (_) {
      if (tokensProvider.tokens.isEmpty) {
        tokensProvider.updateDummyData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TokensProvider, IntervalProvider>(
      builder: (context, tokensProvider, intervalProvider, child) {
        final selectedInterval = intervalProvider.selectedInterval;

        // sort by change%
        final tokens = List.from(tokensProvider.tokens)
          ..sort(
            (a, b) => b
                .priceChange(selectedInterval)
                .compareTo(a.priceChange(selectedInterval)),
          );

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
                intervals: const ['5m', '15m', '30m', '1h', '1d'],
              ),

              // -----------------------------
              // Interval Countdown
              // -----------------------------
              const IntervalCountdownWidget(),

              const SizedBox(height: KSpacing.md),

              // -----------------------------
              // Tokens List
              // -----------------------------
              Expanded(
                child: tokensProvider.isConnected && tokens.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
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
                              currentPrice: token.closePrice(selectedInterval),
                              selectedIntervalChange: token.priceChange(
                                selectedInterval,
                              ),
                              dailyChange: token.priceChange('1d'),
                              volume: token.volume(selectedInterval),
                              netVolume: token.netVolume(selectedInterval),
                              marketCap: token.marketCap,
                              sparklineData: token.sparkline(selectedInterval),
                              indicators: token.indicators,
                              // trade button presses
                              onBuyPressed: () => {
                                _handleTrade(
                                  action: Provider.of<TestTradeActionProvider>(
                                    context,
                                    listen: false,
                                  ).action,
                                  symbol: 'BTCUSDT',
                                  requestedLeverage: 3,
                                  // baseAmount: 0.05,
                                  // stopLossPercent: 2,
                                  // takeProfitPercent: 5,
                                ),
                                Provider.of<TestTradeActionProvider>(
                                  context,
                                  listen: false,
                                ).updateAction(),
                              },
                              onQuickBuyPressed: () => _handleTrade(
                                action: 'buy',
                                symbol: token.name,
                                requestedLeverage: AppConfig.requestedLaverage,
                              ),
                              onSellPressed: () => _handleTrade(
                                action: 'sell',
                                symbol: token.name,
                              ),
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
