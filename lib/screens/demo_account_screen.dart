import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/demo_paper_account.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/utils/constants.dart';

class DemoAccountScreen extends StatefulWidget {
  const DemoAccountScreen({super.key, this.autoFetch = true});

  final bool autoFetch;

  @override
  State<DemoAccountScreen> createState() => _DemoAccountScreenState();
}

class _DemoAccountScreenState extends State<DemoAccountScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.autoFetch) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TokensProvider>().fetchDemoPaperAccount();
    });
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
    return signalType == 'elastic'
        ? KColors.signalElastic
        : KColors.signalSetup;
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
        return Container(
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.controlBackground,
        border: Border.all(
          color: _resultColor(
            position.unrealizedPnlUsdt,
          ).withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
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
    );
  }

  Widget _buildAcceptedDecisionPlan(DemoPaperDecisionPlan plan) {
    final signalColor = _signalColor(plan.signalType);
    final orderText =
        plan.entryOrderType == 'LIMIT' && plan.plannedLimitPrice > 0
        ? 'LIMIT ${plan.plannedLimitPrice.toStringAsPrecision(6)}'
        : plan.entryOrderType;

    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: signalColor.withValues(alpha: 0.08),
        border: Border.all(color: signalColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
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
    );
  }

  Widget _buildDecisionRejection(DemoPaperDecisionRejection rejection) {
    final hasToken = rejection.tokenName.isNotEmpty;
    final signalColor = _signalColor(rejection.signalType);

    return Container(
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

    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.controlBackground,
        border: Border.all(color: KColors.controlBorder),
        borderRadius: BorderRadius.circular(KSizes.scannerControlBorderRadius),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TokensProvider>(
      builder: (context, tokensProvider, child) {
        final account = tokensProvider.demoPaperAccount;
        final closedTrades = account.closedTrades;

        return Scaffold(
          backgroundColor: KColors.background,
          appBar: AppBar(
            title: const Text('Demo Account', style: KTextStyles.appBarTitle),
            backgroundColor: Colors.transparent,
            centerTitle: true,
            elevation: 0,
          ),
          body: RefreshIndicator(
            onRefresh: tokensProvider.fetchDemoPaperAccount,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KSizes.listViewHorizontalPadding,
                KSpacing.sm,
                KSizes.listViewHorizontalPadding,
                KSizes.navBarHeight + KSpacing.xl,
              ),
              children: [
                if (tokensProvider.isDemoPaperAccountLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Text(
                  'Paper mode - no real orders',
                  style: KTextStyles.scannerMeta,
                ),
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
                      'No paper trades closed yet. If you manually cleared the demo history file, this starts fresh from the next live paper trade.',
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
              ],
            ),
          ),
        );
      },
    );
  }
}
