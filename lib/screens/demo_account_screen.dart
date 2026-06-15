import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/demo_paper_account.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/providers/trade_mode_provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/screens/individual_token_screen.dart';
import 'package:cndlclar/services/kline_service.dart';
import 'package:cndlclar/services/trade_service.dart';
import 'package:cndlclar/utils/constants.dart';
import 'package:cndlclar/utils/config.dart';

class DemoAccountScreen extends StatefulWidget {
  const DemoAccountScreen({super.key, this.autoFetch = true});

  final bool autoFetch;

  @override
  State<DemoAccountScreen> createState() => _DemoAccountScreenState();
}

class _DemoAccountScreenState extends State<DemoAccountScreen> {
  final KlineService _klineService = KlineService(baseUrl: AppConfig.baseUrl);
  final TradeService _tradeService = TradeService();
  final Map<String, Map<String, List<KlineData>>> _historicalKlines = {};
  final Set<String> _historicalFetchesInFlight = {};

  @override
  void initState() {
    super.initState();
    if (!widget.autoFetch) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshActiveAccount();
    });
  }

  Future<void> _refreshActiveAccount() {
    final isDemoMode = context.read<TradeModeProvider>().isDemoMode;
    return isDemoMode
        ? context.read<TokensProvider>().fetchDemoPaperAccount()
        : context.read<TokensProvider>().fetchRealTradeAccount();
  }

  String _formatMoney(double value) {
    final prefix = value >= 0 ? '' : '-';
    return '$prefix\$${value.abs().toStringAsFixed(2)}';
  }

  String _formatSignedMoney(double value) {
    final prefix = value >= 0 ? '+' : '-';
    return '$prefix\$${value.abs().toStringAsFixed(2)}';
  }

  String _formatPercent(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'waiting';

    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  String _formatCompactNumber(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals);
  }

  String _formatDecisionReason(String value) {
    switch (value) {
      case 'POSITION_OPEN':
        return 'Position already open';
      case 'PENDING_ENTRY_ACTIVE':
        return 'Limit entry is waiting';
      case 'NO_PAPER_BALANCE':
        return 'No paper balance';
      case 'GLOBAL_COOLDOWN_AFTER_SELL':
        return 'Cooling down after sell';
      case 'SYMBOL_COOLDOWN':
        return 'Symbol cooldown';
      case 'NEGATIVE_SIGNAL_REASON':
        return 'Negative signal reason';
      case 'WEAK_MOMENTUM_OR_NO_ROOM':
        return 'Weak momentum or no room';
      case 'INVALID_PULLBACK_PRICE':
        return 'Invalid EMA pullback price';
      case 'ENTRY_FILTERS_NOT_MET':
        return 'Entry filters not met';
      case 'NO_LIVE_PRICE':
        return 'No live price';
      default:
        return value
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  String _formatStrategy(String value) {
    switch (value) {
      case 'ACTIVE_SCALP':
        return 'Active scalp';
      case 'MARKET_MOMENTUM_OCO':
        return 'Momentum OCO';
      case 'EMA_PULLBACK_LIMIT_OCO':
        return 'EMA pullback limit';
      case 'EMA_CONFIRMATION_OCO':
        return 'EMA confirmation';
      default:
        return _formatDecisionReason(value);
    }
  }

  Color _resultColor(double value) {
    return value >= 0 ? KColors.accentPositive : KColors.accentNegative;
  }

  Color _signalColor(String signalType) {
    if (signalType == 'elastic') return KColors.signalElastic;
    if (signalType == 'structure') return KColors.signalStructure;
    return KColors.signalSetup;
  }

  Token? _liveTokenForSymbol(String symbol) {
    final tokens = context.read<TokensProvider>().tokens;
    for (final token in tokens) {
      if (token.name == symbol) return token;
    }
    return null;
  }

  Token _fallbackTokenForSymbol(String symbol, double price) {
    final safePrice = price > 0 ? price : 0.0;
    const intervals = ['1m', '3m', '5m', '15m', '30m', '1h', '1d'];

    return Token(
      name: symbol,
      marketCap: 0,
      indicators: const [],
      tickerPriceChange1h: 0,
      rollingPriceChangePerInterval: {
        for (final interval in intervals) interval: 0,
      },
      rollingPriceChangeReadyPerInterval: {
        for (final interval in intervals) interval: false,
      },
      openPricePerInterval: {
        for (final interval in intervals) interval: safePrice,
      },
      closePricePerInterval: {
        for (final interval in intervals) interval: safePrice,
      },
      highPricePerInterval: {
        for (final interval in intervals) interval: safePrice,
      },
      lowPricePerInterval: {
        for (final interval in intervals) interval: safePrice,
      },
      priceChangePercentPerInterval: {
        for (final interval in intervals) interval: 0,
      },
      volumePerInterval: {for (final interval in intervals) interval: 0},
      netVolumePerInterval: {for (final interval in intervals) interval: 0},
      intervalStartTimes: const {},
      intervalClosedPerInterval: {
        for (final interval in intervals) interval: false,
      },
      sparklineData: const {},
      sparklineDataOriginal: const {},
    );
  }

  Future<void> _ensureHistoricalKlines(String symbol) async {
    final selectedInterval = context.read<IntervalProvider>().selectedInterval;
    if (_historicalKlines[symbol]?[selectedInterval]?.isNotEmpty == true) {
      return;
    }

    final key = '$symbol|$selectedInterval';
    if (_historicalFetchesInFlight.contains(key)) return;

    _historicalFetchesInFlight.add(key);
    try {
      final candles = await _klineService.fetchHistoricalKlines(
        symbol: symbol,
        interval: selectedInterval,
        limit: 50,
      );

      if (!mounted || candles.isEmpty) return;
      setState(() {
        _historicalKlines[symbol] ??= {};
        _historicalKlines[symbol]![selectedInterval] = candles;
      });
    } finally {
      _historicalFetchesInFlight.remove(key);
    }
  }

  Future<void> _handleTrade({
    required String action,
    required String symbol,
    String? actionLabel,
    double? currentPrice,
    int? requestedLeverage,
    double? stopLossPercent,
    double? takeProfitPercent,
    double? autoSellProfitPercent,
    String? interval,
  }) async {
    final result = await _tradeService.executeTrade(
      action: action,
      symbol: symbol,
      demoMode: true,
      currentPrice: currentPrice ?? _tradeCurrentPrice(symbol),
      requestedLeverage: requestedLeverage,
      stopLossPercent: stopLossPercent,
      takeProfitPercent: takeProfitPercent,
      autoSellProfitPercent: autoSellProfitPercent,
      interval: interval,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      final isAccepted = data['status']?.toString() == 'accepted';
      final statusLabel = isAccepted ? 'Accepted' : 'Successful';
      final displayAction = actionLabel ?? action.toUpperCase();
      final message = data['data']?['message']?.toString() ?? '';
      await context.read<TokensProvider>().fetchDemoPaperAccount();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$displayAction $statusLabel: $message',
            style: const TextStyle(color: KColors.textPrimary),
          ),
          backgroundColor: KColors.tradeSuccessfulSnackbar,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trade failed: ${result['error']}',
            style: const TextStyle(color: KColors.textPrimary),
          ),
          backgroundColor: KColors.tradeFailedSnackbar,
        ),
      );
    }
  }

  Future<void> _cancelDemoPendingOrder(String symbol) async {
    final result = await _tradeService.executeTrade(
      action: 'cancel-pending',
      symbol: symbol,
      demoMode: true,
    );

    if (!mounted) return;

    await context.read<TokensProvider>().fetchDemoPaperAccount();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Demo pending $symbol order cancelled.'
              : 'Cancel failed: ${result['error']}',
          style: const TextStyle(color: KColors.textPrimary),
        ),
        backgroundColor: result['success'] == true
            ? KColors.tradeSuccessfulSnackbar
            : KColors.tradeFailedSnackbar,
      ),
    );
  }

  Future<void> _cancelRealWaitingOrder(String symbol) async {
    final result = await _tradeService.executeTrade(
      action: 'cancel-waiting-order',
      symbol: symbol,
    );

    if (!mounted) return;

    await context.read<TokensProvider>().fetchRealTradeAccount();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Real $symbol waiting/open order cancel requested.'
              : 'Cancel failed: ${result['error']}',
          style: const TextStyle(color: KColors.textPrimary),
        ),
        backgroundColor: result['success'] == true
            ? KColors.tradeSuccessfulSnackbar
            : KColors.tradeFailedSnackbar,
      ),
    );
  }

  double _tradeCurrentPrice(String symbol, [double fallbackPrice = 0]) {
    final token = _liveTokenForSymbol(symbol);
    if (token != null) {
      for (final interval in const ['1m', '5m', '15m', '30m', '1h', '1d']) {
        final price = token.closePrice(interval);
        if (price > 0) return price;
      }
    }

    return fallbackPrice;
  }

  Future<void> _openTokenScreen(
    String symbol, {
    double fallbackPrice = 0,
  }) async {
    if (symbol.isEmpty) return;

    await _ensureHistoricalKlines(symbol);
    if (!mounted) return;

    final token =
        _liveTokenForSymbol(symbol) ??
        _fallbackTokenForSymbol(symbol, fallbackPrice);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IndividualTokenScreen(
          token: token,
          historicalKlines: _historicalKlines,
          onEma7LimitOcoPressed: () => _handleTrade(
            action: 'ema7-limit-buy-oco',
            actionLabel: 'EMA7 Limit + OCO',
            symbol: symbol,
            currentPrice: _tradeCurrentPrice(symbol, fallbackPrice),
            requestedLeverage: AppConfig.requestedLaverage,
            stopLossPercent: 1.5,
            takeProfitPercent: 2,
          ),
          onMarketAutoClosePressed: () => _handleTrade(
            action: 'market-buy-auto-close',
            actionLabel: '5m Auto Sell',
            symbol: symbol,
            currentPrice: _tradeCurrentPrice(symbol, fallbackPrice),
            requestedLeverage: AppConfig.requestedLaverage,
            stopLossPercent: 1.5,
            takeProfitPercent: 2,
            autoSellProfitPercent: 0.45,
            interval: '5m',
          ),
          onBuyPressed: () => _handleTrade(
            action: 'buy',
            symbol: symbol,
            currentPrice: _tradeCurrentPrice(symbol, fallbackPrice),
            requestedLeverage: AppConfig.requestedLaverage,
            stopLossPercent: 1.5,
            takeProfitPercent: 2,
          ),
          onQuickBuyPressed: () => _handleTrade(
            action: 'buy',
            symbol: symbol,
            currentPrice: _tradeCurrentPrice(symbol, fallbackPrice),
            requestedLeverage: AppConfig.requestedLaverage,
          ),
          onSellPressed: () => _handleTrade(
            action: 'sell',
            symbol: symbol,
            currentPrice: _tradeCurrentPrice(symbol, fallbackPrice),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenTapTarget({
    required String symbol,
    required Widget child,
    double fallbackPrice = 0,
  }) {
    if (symbol.isEmpty) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
        onTap: () => _openTokenScreen(symbol, fallbackPrice: fallbackPrice),
        child: child,
      ),
    );
  }

  Widget _buildPanel({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.controlBackground,
        border: Border.all(color: borderColor ?? KColors.controlBorder),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: child,
    );
  }

  Widget _buildDecisionChip({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: KColors.background.withValues(alpha: 0.32),
        border: Border.all(color: KColors.controlBorder),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: Text(
        '$label $value',
        style: KTextStyles.tokenMetricLabel.copyWith(
          color: valueColor ?? KColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDecisionMetrics(DemoPaperDecisionMetrics metrics) {
    return Wrap(
      spacing: KSpacing.xs,
      runSpacing: KSpacing.xs,
      children: [
        _buildDecisionChip(
          label: 'R5',
          value: _formatPercent(metrics.rolling5m),
          valueColor: _resultColor(metrics.rolling5m),
        ),
        _buildDecisionChip(
          label: 'R15',
          value: _formatPercent(metrics.rolling15m),
          valueColor: _resultColor(metrics.rolling15m),
        ),
        _buildDecisionChip(
          label: 'R30',
          value: _formatPercent(metrics.rolling30m),
          valueColor: _resultColor(metrics.rolling30m),
        ),
        _buildDecisionChip(
          label: 'EMA7',
          value: _formatPercent(metrics.closeMinusEma7),
        ),
        _buildDecisionChip(
          label: 'RV',
          value: '${_formatCompactNumber(metrics.relativeVolume5m)}x',
        ),
        _buildDecisionChip(
          label: 'RSI',
          value:
              '${metrics.rsi3.toStringAsFixed(0)}/${metrics.rsi14.toStringAsFixed(0)}/${metrics.rsi50.toStringAsFixed(0)}',
        ),
        _buildDecisionChip(
          label: 'BOLL',
          value: _formatPercent(metrics.bollUpperRoom),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, KSpacing.lg, 0, KSpacing.sm),
      child: Text(title, style: KTextStyles.tokenName),
    );
  }

  Widget _buildModeSelector(TradeModeProvider tradeModeProvider) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(value: true, label: Text('Demo')),
        ButtonSegment<bool>(value: false, label: Text('Real')),
      ],
      selected: {tradeModeProvider.isDemoMode},
      onSelectionChanged: (selection) async {
        final isDemoMode = selection.first;
        tradeModeProvider.setDemoMode(isDemoMode);
        if (isDemoMode) {
          await context.read<TokensProvider>().fetchDemoPaperAccount();
        } else {
          await context.read<TokensProvider>().fetchRealTradeAccount();
        }
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: KColors.controlBackground,
          border: Border.all(color: KColors.controlBorder),
          borderRadius: BorderRadius.circular(
            KSizes.scannerControlBorderRadius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: KTextStyles.tokenMetricLabel),
            const SizedBox(height: KSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KTextStyles.tokenMetricValue.copyWith(
                color: color ?? KColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSummary(DemoPaperAccount account) {
    return Column(
      children: [
        Row(
          children: [
            _buildMetricTile(
              label: 'Balance',
              value: _formatMoney(account.balanceUsdt),
              color: _resultColor(
                account.balanceUsdt - account.startingBalanceUsdt,
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            _buildMetricTile(
              label: 'Trade size',
              value: _formatMoney(account.notionalPerTradeUsdt),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        Row(
          children: [
            _buildMetricTile(
              label: 'Realized P/L',
              value: _formatSignedMoney(account.stats.realizedPnlUsdt),
              color: _resultColor(account.stats.realizedPnlUsdt),
            ),
            const SizedBox(width: KSpacing.sm),
            _buildMetricTile(
              label: 'Win rate',
              value:
                  '${account.stats.winRate.toStringAsFixed(0)}% / ${account.stats.totalClosedTrades}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpenPosition(DemoPaperAccount account) {
    final position = account.openPosition;
    if (position == null) {
      final pendingOrder = account.pendingOrder;
      if (pendingOrder != null) {
        return _buildTokenTapTarget(
          symbol: pendingOrder.symbol,
          fallbackPrice: pendingOrder.currentPrice > 0
              ? pendingOrder.currentPrice
              : pendingOrder.plannedLimitPrice,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: KColors.controlBackground,
              border: Border.all(
                color: KColors.signalSetup.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(
                KSizes.scannerControlBorderRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pendingOrder.symbol.replaceAll('USDT', '/USDT'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KTextStyles.tokenName,
                      ),
                    ),
                    Text(
                      'WAIT LIMIT',
                      style: KTextStyles.signalScore.copyWith(
                        color: KColors.signalSetup,
                      ),
                    ),
                    const SizedBox(width: KSpacing.xs),
                    TextButton(
                      onPressed: () =>
                          _cancelDemoPendingOrder(pendingOrder.symbol),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.sm),
                Row(
                  children: [
                    _buildMetricTile(
                      label: 'Limit',
                      value: pendingOrder.plannedLimitPrice.toStringAsPrecision(
                        6,
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    _buildMetricTile(
                      label: 'Now',
                      value: pendingOrder.currentPrice.toStringAsPrecision(6),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  '${pendingOrder.entryStrategy} - expires ${_formatDate(pendingOrder.expiresAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KTextStyles.scannerMeta,
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: KColors.controlBackground,
          border: Border.all(color: KColors.controlBorder),
          borderRadius: BorderRadius.circular(
            KSizes.scannerControlBorderRadius,
          ),
        ),
        child: Text(
          'No demo position open right now.',
          style: KTextStyles.scannerMeta,
        ),
      );
    }

    return _buildTokenTapTarget(
      symbol: position.symbol,
      fallbackPrice: position.currentPrice > 0
          ? position.currentPrice
          : position.entryPrice,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: KColors.controlBackground,
          border: Border.all(
            color: _resultColor(
              position.unrealizedPnlUsdt,
            ).withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(
            KSizes.scannerControlBorderRadius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    position.symbol.replaceAll('USDT', '/USDT'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.tokenName,
                  ),
                ),
                Text(
                  position.signalType.toUpperCase(),
                  style: KTextStyles.signalScore.copyWith(
                    color: position.signalType == 'elastic'
                        ? KColors.signalElastic
                        : KColors.signalSetup,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                _buildMetricTile(
                  label: 'Entry',
                  value: position.entryPrice.toStringAsPrecision(6),
                ),
                const SizedBox(width: KSpacing.sm),
                _buildMetricTile(
                  label: 'Now',
                  value: position.currentPrice.toStringAsPrecision(6),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                _buildMetricTile(
                  label: 'Move',
                  value: _formatPercent(position.unrealizedPriceChangePercent),
                  color: _resultColor(position.unrealizedPriceChangePercent),
                ),
                const SizedBox(width: KSpacing.sm),
                _buildMetricTile(
                  label: 'P/L',
                  value: _formatSignedMoney(position.unrealizedPnlUsdt),
                  color: _resultColor(position.unrealizedPnlUsdt),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              '${position.leverage.toStringAsFixed(0)}x - held ${_formatSeconds(position.holdSeconds)}',
              style: KTextStyles.scannerMeta,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedDecisionPlan(DemoPaperDecisionPlan plan) {
    final signalColor = _signalColor(plan.signalType);
    final orderText =
        plan.entryOrderType == 'LIMIT' && plan.plannedLimitPrice > 0
        ? 'LIMIT ${plan.plannedLimitPrice.toStringAsPrecision(6)}'
        : plan.entryOrderType;

    return _buildTokenTapTarget(
      symbol: plan.tokenName,
      fallbackPrice: plan.currentPrice,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.sm),
        decoration: BoxDecoration(
          color: signalColor.withValues(alpha: 0.08),
          border: Border.all(color: signalColor.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(
            KSizes.scannerControlBorderRadius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.tokenName.replaceAll('USDT', '/USDT'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.tokenMetricValue,
                  ),
                ),
                Text(
                  plan.signalType.toUpperCase(),
                  style: KTextStyles.signalScore.copyWith(color: signalColor),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              '${_formatStrategy(plan.strategy)} - $orderText - score ${plan.qualityScore.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KTextStyles.scannerMeta,
            ),
            const SizedBox(height: KSpacing.sm),
            Wrap(
              spacing: KSpacing.xs,
              runSpacing: KSpacing.xs,
              children: [
                _buildDecisionChip(
                  label: 'Target',
                  value: _formatPercent(plan.targetProfitPercent),
                  valueColor: KColors.accentPositive,
                ),
                _buildDecisionChip(
                  label: 'Stop',
                  value: _formatPercent(plan.stopLossPercent),
                  valueColor: KColors.accentNegative,
                ),
                _buildDecisionChip(
                  label: 'Now',
                  value: plan.currentPrice.toStringAsPrecision(6),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            _buildDecisionMetrics(plan.metrics),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionRejection(DemoPaperDecisionRejection rejection) {
    final hasToken = rejection.tokenName.isNotEmpty;
    final signalColor = _signalColor(rejection.signalType);

    final card = Container(
      margin: const EdgeInsets.only(top: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: KColors.background.withValues(alpha: 0.2),
        border: Border.all(color: KColors.controlBorder),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasToken
                      ? rejection.tokenName.replaceAll('USDT', '/USDT')
                      : 'Scanner state',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KTextStyles.tokenMetricValue,
                ),
              ),
              if (hasToken)
                Text(
                  rejection.score.toStringAsFixed(1),
                  style: KTextStyles.signalScore.copyWith(color: signalColor),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            _formatDecisionReason(rejection.reason),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KTextStyles.scannerMeta,
          ),
          if (hasToken) ...[
            const SizedBox(height: KSpacing.sm),
            _buildDecisionMetrics(rejection.metrics),
          ],
        ],
      ),
    );

    if (!hasToken) return card;
    return _buildTokenTapTarget(symbol: rejection.tokenName, child: card);
  }

  Widget _buildDecisionSnapshot(DemoPaperAccount account) {
    final snapshot = account.decisionSnapshot;
    if (snapshot == null) {
      return _buildPanel(
        child: Text(
          'Waiting for the backend scanner to send its first paper decision.',
          style: KTextStyles.scannerMeta,
        ),
      );
    }

    final acceptedPlan = snapshot.acceptedPlan;
    final rejections = snapshot.topRejections.take(5).toList(growable: false);

    return _buildPanel(
      borderColor: acceptedPlan == null
          ? KColors.controlBorder
          : _signalColor(acceptedPlan.signalType).withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last scan ${_formatDate(snapshot.evaluatedAt)}',
                  style: KTextStyles.tokenMetricValue,
                ),
              ),
              Text(
                '${snapshot.rankedSignalCount} candidates',
                style: KTextStyles.scannerMeta,
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          if (snapshot.rankedSignalCount == 0)
            Text(
              'No ranked short-term candidates yet. After clearing history, the paper account is fresh and will wait for the next live scanner setup.',
              style: KTextStyles.scannerMeta,
            )
          else if (acceptedPlan != null) ...[
            Text('Next accepted plan', style: KTextStyles.tokenMetricLabel),
            const SizedBox(height: KSpacing.xs),
            _buildAcceptedDecisionPlan(acceptedPlan),
          ] else
            Text(
              'No trade accepted on this scan. Top reasons are below.',
              style: KTextStyles.scannerMeta,
            ),
          if (rejections.isNotEmpty) ...[
            const SizedBox(height: KSpacing.sm),
            Text('Top rejected checks', style: KTextStyles.tokenMetricLabel),
            ...rejections.map(_buildDecisionRejection),
          ],
        ],
      ),
    );
  }

  Widget _buildTradeTile(DemoPaperTrade trade) {
    final resultColor = _resultColor(trade.profitLossUsdt);

    return _buildTokenTapTarget(
      symbol: trade.symbol,
      fallbackPrice: trade.exitPrice > 0 ? trade.exitPrice : trade.entryPrice,
      child: Container(
        margin: const EdgeInsets.only(bottom: KSpacing.sm),
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: KColors.controlBackground,
          border: Border.all(color: KColors.controlBorder),
          borderRadius: BorderRadius.circular(
            KSizes.scannerControlBorderRadius,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trade.symbol.replaceAll('USDT', '/USDT'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.tokenMetricValue,
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    '${_formatDate(trade.closedAt)} - ${trade.exitReason}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.tokenMetricLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatSignedMoney(trade.profitLossUsdt),
                  style: KTextStyles.tokenMetricValue.copyWith(
                    color: resultColor,
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  _formatPercent(trade.priceChangePercent),
                  style: KTextStyles.tokenMetricLabel.copyWith(
                    color: _resultColor(trade.priceChangePercent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  double _numberValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _stringValue(dynamic value, [String fallback = '']) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  DateTime? _dateValue(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }

  Widget _buildRealAccountSummary(Map<String, dynamic> account) {
    final balance = _mapValue(account['balance']);
    final usdt = _mapValue(balance?['usdt']);
    final openPositions = _mapList(account['openPositions']);
    final openOrders = _mapList(account['openOrders']);
    final activeStrategies = _mapList(account['activeStrategies']);
    final stats = _mapValue(account['stats']);
    final error = _stringValue(account['error']);

    return Column(
      children: [
        if (error.isNotEmpty) ...[
          _buildPanel(
            borderColor: KColors.accentWarning,
            child: Text(error, style: KTextStyles.scannerMeta),
          ),
          const SizedBox(height: KSpacing.sm),
        ],
        Row(
          children: [
            _buildMetricTile(
              label: 'USDT free',
              value: _formatMoney(_numberValue(usdt?['free'])),
            ),
            const SizedBox(width: KSpacing.sm),
            _buildMetricTile(
              label: 'USDT borrowed',
              value: _formatMoney(_numberValue(usdt?['borrowed'])),
              color: KColors.accentWarning,
            ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        Row(
          children: [
            _buildMetricTile(
              label: 'Waiting',
              value: '${activeStrategies.length + openOrders.length}',
            ),
            const SizedBox(width: KSpacing.sm),
            _buildMetricTile(
              label: 'Positions',
              value: '${openPositions.length}',
            ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        Row(
          children: [
            _buildMetricTile(
              label: 'Realized P/L',
              value: _formatSignedMoney(
                _numberValue(stats?['realizedPnlUSDT']),
              ),
              color: _resultColor(_numberValue(stats?['realizedPnlUSDT'])),
            ),
            const SizedBox(width: KSpacing.sm),
            _buildMetricTile(
              label: 'Margin level',
              value: _numberValue(balance?['marginLevel']).toStringAsFixed(2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRealWaitingOrders(Map<String, dynamic> account) {
    final activeStrategies = _mapList(account['activeStrategies']);
    final openOrders = _mapList(account['openOrders']);

    if (activeStrategies.isEmpty && openOrders.isEmpty) {
      return _buildPanel(
        child: Text(
          'No real waiting orders found on the backend.',
          style: KTextStyles.scannerMeta,
        ),
      );
    }

    return Column(
      children: [
        ...activeStrategies.map((strategy) {
          final symbol = _stringValue(strategy['symbol']);
          return _buildRealWaitingTile(
            symbol: symbol,
            title: symbol.replaceAll('USDT', '/USDT'),
            status: _stringValue(strategy['status'], 'WAITING'),
            detail:
                'EMA${_stringValue(strategy['emaPeriod'], '7')} ${_stringValue(strategy['interval'], '5m')} - target ${_formatDate(_dateValue(strategy['targetStartTime']))}',
          );
        }),
        ...openOrders.map((order) {
          final symbol = _stringValue(order['symbol']);
          final type = _stringValue(order['type'], 'ORDER');
          final side = _stringValue(order['side']);
          final price = _numberValue(order['price']);
          final error = _stringValue(order['error']);
          return _buildRealWaitingTile(
            symbol: symbol,
            title: symbol.replaceAll('USDT', '/USDT'),
            status: error.isEmpty ? '$side $type' : 'ORDER ERROR',
            detail: error.isEmpty
                ? 'Price ${price.toStringAsPrecision(6)} - ${_stringValue(order['status'], 'open')}'
                : error,
          );
        }),
      ],
    );
  }

  Widget _buildRealWaitingTile({
    required String symbol,
    required String title,
    required String status,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.controlBackground,
        border: Border.all(color: KColors.accentWarning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTokenTapTarget(
              symbol: symbol,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: KTextStyles.tokenMetricValue),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    '$status - $detail',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.scannerMeta,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          TextButton(
            onPressed: symbol.isEmpty
                ? null
                : () => _cancelRealWaitingOrder(symbol),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRealOpenPositions(Map<String, dynamic> account) {
    final positions = _mapList(account['openPositions']);
    if (positions.isEmpty) {
      return _buildPanel(
        child: Text(
          'No local real open positions recorded.',
          style: KTextStyles.scannerMeta,
        ),
      );
    }

    return Column(
      children: positions
          .map((position) {
            final symbol = _stringValue(position['symbol']);
            final entryPrice = _numberValue(position['entryPrice']) > 0
                ? _numberValue(position['entryPrice'])
                : _numberValue(position['avgPrice']);
            final qty = _numberValue(position['executedQty']) > 0
                ? _numberValue(position['executedQty'])
                : _numberValue(position['roundedQty']);
            return _buildTokenTapTarget(
              symbol: symbol,
              fallbackPrice: entryPrice,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: KSpacing.sm),
                padding: const EdgeInsets.all(KSpacing.md),
                decoration: BoxDecoration(
                  color: KColors.controlBackground,
                  border: Border.all(color: KColors.controlBorder),
                  borderRadius: BorderRadius.circular(
                    KSizes.scannerControlBorderRadius,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        symbol.replaceAll('USDT', '/USDT'),
                        style: KTextStyles.tokenMetricValue,
                      ),
                    ),
                    Text(
                      '${qty.toStringAsPrecision(6)} @ ${entryPrice.toStringAsPrecision(6)}',
                      style: KTextStyles.scannerMeta,
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildRealTradeHistory(Map<String, dynamic> account) {
    final trades = _mapList(account['tradeHistory']).reversed.take(30);
    if (trades.isEmpty) {
      return _buildPanel(
        child: Text(
          'No real trade history found on the VPS yet.',
          style: KTextStyles.scannerMeta,
        ),
      );
    }

    return Column(
      children: trades
          .map((trade) {
            final symbol = _stringValue(trade['symbol']);
            final pnl = _numberValue(trade['profitLossUSDT']);
            final status = _stringValue(
              trade['status'],
              _stringValue(
                trade['type'],
                _stringValue(trade['eventType'], 'trade'),
              ),
            );
            return _buildTokenTapTarget(
              symbol: symbol,
              fallbackPrice: _numberValue(trade['avgPrice']),
              child: Container(
                margin: const EdgeInsets.only(bottom: KSpacing.sm),
                padding: const EdgeInsets.all(KSpacing.md),
                decoration: BoxDecoration(
                  color: KColors.controlBackground,
                  border: Border.all(color: KColors.controlBorder),
                  borderRadius: BorderRadius.circular(
                    KSizes.scannerControlBorderRadius,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbol.replaceAll('USDT', '/USDT'),
                            style: KTextStyles.tokenMetricValue,
                          ),
                          const SizedBox(height: KSpacing.xs),
                          Text(status, style: KTextStyles.tokenMetricLabel),
                        ],
                      ),
                    ),
                    Text(
                      _formatSignedMoney(pnl),
                      style: KTextStyles.tokenMetricValue.copyWith(
                        color: _resultColor(pnl),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildRealAccountView(TokensProvider tokensProvider) {
    final account = tokensProvider.realTradeAccount;
    if (account == null) {
      return _buildPanel(
        child: Text(
          'Pull to refresh to load real trade data from the VPS.',
          style: KTextStyles.scannerMeta,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountModeNote('Real mode - backend uses your Binance account'),
        const SizedBox(height: KSpacing.sm),
        _buildRealAccountSummary(account),
        _buildSectionTitle('Waiting Orders'),
        _buildRealWaitingOrders(account),
        _buildSectionTitle('Open Positions'),
        _buildRealOpenPositions(account),
        _buildSectionTitle('Trade History'),
        _buildRealTradeHistory(account),
        const SizedBox(height: KSpacing.sm),
        Text(
          'Last update ${_formatDate(_dateValue(account['updatedAt']))}',
          style: KTextStyles.scannerMeta,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAccountModeNote(String text) {
    return Text(text, style: KTextStyles.scannerMeta);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TokensProvider, TradeModeProvider>(
      builder: (context, tokensProvider, tradeModeProvider, child) {
        final account = tokensProvider.demoPaperAccount;
        final closedTrades = account.closedTrades;
        final isDemoMode = tradeModeProvider.isDemoMode;
        if (!isDemoMode &&
            tokensProvider.realTradeAccount == null &&
            !tokensProvider.isRealTradeAccountLoading &&
            widget.autoFetch) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<TokensProvider>().fetchRealTradeAccount();
            }
          });
        }

        return Scaffold(
          backgroundColor: KColors.background,
          appBar: AppBar(
            title: const Text('Account', style: KTextStyles.appBarTitle),
            backgroundColor: Colors.transparent,
            centerTitle: true,
            elevation: 0,
          ),
          body: RefreshIndicator(
            onRefresh: _refreshActiveAccount,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KSizes.listViewHorizontalPadding,
                KSpacing.sm,
                KSizes.listViewHorizontalPadding,
                KSizes.navBarHeight + KSpacing.xl,
              ),
              children: [
                Center(child: _buildModeSelector(tradeModeProvider)),
                const SizedBox(height: KSpacing.sm),
                if (tokensProvider.isDemoPaperAccountLoading ||
                    tokensProvider.isRealTradeAccountLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (isDemoMode) ...[
                  _buildAccountModeNote('Manual demo mode - no real orders'),
                  const SizedBox(height: KSpacing.sm),
                  _buildAccountSummary(account),
                  _buildSectionTitle('Open Position'),
                  _buildOpenPosition(account),
                  _buildSectionTitle('Decision Engine'),
                  _buildDecisionSnapshot(account),
                  _buildSectionTitle('Closed Trades'),
                  if (closedTrades.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(KSpacing.md),
                      decoration: BoxDecoration(
                        color: KColors.controlBackground,
                        border: Border.all(color: KColors.controlBorder),
                        borderRadius: BorderRadius.circular(
                          KSizes.scannerControlBorderRadius,
                        ),
                      ),
                      child: Text(
                        'No manual demo trades closed yet. Use Demo mode trade buttons to record fake buys and sells.',
                        style: KTextStyles.scannerMeta,
                      ),
                    )
                  else
                    ...closedTrades.map(_buildTradeTile),
                  const SizedBox(height: KSpacing.sm),
                  Text(
                    'Last update ${_formatDate(account.updatedAt)}',
                    style: KTextStyles.scannerMeta,
                    textAlign: TextAlign.center,
                  ),
                ] else
                  _buildRealAccountView(tokensProvider),
              ],
            ),
          ),
        );
      },
    );
  }
}
