import 'dart:async';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/services/trade_service.dart';
import 'package:cndlclar/services/kline_service.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/providers/sorting_field_provider.dart';
import 'package:cndlclar/screens/individual_token_screen.dart';
import 'package:cndlclar/widgets/token_list_view_section.dart';
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
  final KlineService _klineService = KlineService(baseUrl: AppConfig.baseUrl);

  //Hhistorical candles per symbol and interval
  final Map<String, Map<String, List<KlineData>>> _historicalKlines = {};

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
            '${action.toUpperCase()} Successful ✅: ${data['data']['message'] ?? ''}',
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

  void _buyPressed(Token token) {
    _handleTrade(
      action: 'buy',
      symbol: token.name,
      requestedLeverage: AppConfig.requestedLaverage,
      stopLossPercent: 1.5,
      takeProfitPercent: 2,
    );
  }

  void _quickBuyPressed(Token token) {
    _handleTrade(
      action: 'buy',
      symbol: token.name,
      requestedLeverage: AppConfig.requestedLaverage,
    );
  }

  void _sellPressed(Token token) {
    _handleTrade(action: 'sell', symbol: token.name);
  }

  Future<void> _fetchAllHistoricalKlines(
    List<Token> tokens,
    String selectedInterval,
  ) async {
    for (final Token token in tokens) {
      _historicalKlines[token.name] ??= {};

      final candles = await _klineService.fetchHistoricalKlines(
        symbol: token.name,
        interval: selectedInterval,
        limit: 50,
      );

      _historicalKlines[token.name]![selectedInterval] = candles;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    // connect to backend
    final tokensProvider = Provider.of<TokensProvider>(context, listen: false);
    tokensProvider.connectToBackend(AppConfig.baseUrl);

    // 2️⃣ Listen for tokens updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tokensProvider.addListener(() {
        if (tokensProvider.tokens.isNotEmpty) {
          final interval = Provider.of<IntervalProvider>(
            context,
            listen: false,
          ).selectedInterval;

          _fetchAllHistoricalKlines(tokensProvider.tokens, interval);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      appBar: AppBar(
        title: const Text('CndlClar', style: KTextStyles.appBarTitle),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: [
          //Set sorting
          IconButton(
            onPressed: () {
              final sortingFieldProvider = Provider.of<SortingFieldProvider>(
                context,
                listen: false,
              );
              sortingFieldProvider.sortingField == 'priceChange'
                  ? sortingFieldProvider.setSortingField('tickerPriceChange1h')
                  : sortingFieldProvider.setSortingField('priceChange');
            },
            icon: const Icon(
              KIcons.setSortingField,
              size: KSizes.navIconSize,
              color: KColors.textPrimary,
            ),
          ),
        ],
      ),
      body: TokenListViewSection(
        showList: true,
        historicalKlines: _historicalKlines,
        onTokenTap: (token) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => IndividualTokenScreen(
                token: token,
                historicalKlines: _historicalKlines,
                onBuyPressed: () => _buyPressed(token),
                onQuickBuyPressed: () => _quickBuyPressed(token),
                onSellPressed: () => _sellPressed(token),
              ),
            ),
          );
        },
        onBuyPressed: _buyPressed,
        onQuickBuyPressed: _quickBuyPressed,
        onSellPressed: _sellPressed,
      ),
    );
  }
}
