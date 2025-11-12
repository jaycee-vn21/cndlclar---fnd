import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/providers/sorting_field_provider.dart';
import 'package:cndlclar/widgets/interval_selector_widget.dart';
import 'package:cndlclar/widgets/interval_countdown_widget.dart';
import 'package:cndlclar/widgets/token_card_widget.dart';
import 'package:cndlclar/utils/constants.dart';

class TokenListViewSection extends StatelessWidget {
  final bool showList;
  final Token? singleToken;
  final Function(Token)? onTokenTap;

  // trade button handlers
  final Function(Token)? onBuyPressed;
  final Function(Token)? onQuickBuyPressed;
  final Function(Token)? onSellPressed;

  const TokenListViewSection({
    super.key,
    this.showList = true,
    this.singleToken,
    this.onTokenTap,
    this.onBuyPressed,
    this.onQuickBuyPressed,
    this.onSellPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<TokensProvider, IntervalProvider, SortingFieldProvider>(
      builder:
          (
            context,
            tokensProvider,
            intervalProvider,
            sortingFieldProvider,
            child,
          ) {
            final selectedInterval = intervalProvider.selectedInterval;
            final sortField = sortingFieldProvider.sortingField;

            final tokens = showList
                ? (List<Token>.from(tokensProvider.tokens)..sort((a, b) {
                    double aValue;
                    double bValue;

                    // Determine sorting field dynamically
                    switch (sortField) {
                      case 'tickerPriceChange1h':
                        aValue = a.tickerPriceChange1h;
                        bValue = b.tickerPriceChange1h;
                        break;
                      case 'priceChange':
                        aValue = a.priceChange(selectedInterval);
                        bValue = b.priceChange(selectedInterval);
                        break;
                      default:
                        aValue = a.priceChange(selectedInterval);
                        bValue = b.priceChange(selectedInterval);
                    }

                    return bValue.compareTo(aValue); // descending
                  }))
                : [
                    tokensProvider.tokens.firstWhere(
                      (t) => t.name == singleToken?.name,
                      orElse: () => singleToken!,
                    ),
                  ];

            return Column(
              children: [
                // Interval Selector
                IntervalSelectorWidget(
                  intervals: const ['5m', '15m', '30m', '1h', '1d'],
                ),

                // Interval Countdown
                const IntervalCountdownWidget(),

                const SizedBox(height: KSpacing.md),

                // Tokens List or Single Token
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
                            return InkWell(
                              onTap: onTokenTap != null
                                  ? () => onTokenTap!(token)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: KSpacing.md,
                                ),
                                child: TokenCardWidget(
                                  tokenName: token.name,
                                  currentPrice: token.closePrice(
                                    selectedInterval,
                                  ),
                                  selectedIntervalChange: token.priceChange(
                                    selectedInterval,
                                  ),
                                  tickerPriceChange1h:
                                      token.tickerPriceChange1h,
                                  dailyChange: token.priceChange('1d'),
                                  volume: token.volume(selectedInterval),
                                  netVolume: token.netVolume(selectedInterval),
                                  marketCap: token.marketCap,
                                  sparklineData: token.sparkline(
                                    selectedInterval,
                                  ),
                                  indicators: token.indicators,
                                  onBuyPressed: () => onBuyPressed?.call(token),
                                  onQuickBuyPressed: () =>
                                      onQuickBuyPressed?.call(token),
                                  onSellPressed: () =>
                                      onSellPressed?.call(token),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
    );
  }
}
