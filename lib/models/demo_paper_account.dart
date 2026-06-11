class DemoPaperAccount {
  const DemoPaperAccount({
    required this.mode,
    required this.startingBalanceUsdt,
    required this.balanceUsdt,
    required this.leverage,
    required this.notionalPerTradeUsdt,
    required this.targetProfitPercent,
    required this.stopLossPercent,
    required this.maxHoldSeconds,
    required this.openPosition,
    required this.pendingOrder,
    required this.decisionSnapshot,
    required this.tradeHistory,
    required this.stats,
    required this.updatedAt,
  });

  final String mode;
  final double startingBalanceUsdt;
  final double balanceUsdt;
  final double leverage;
  final double notionalPerTradeUsdt;
  final double targetProfitPercent;
  final double stopLossPercent;
  final int maxHoldSeconds;
  final DemoPaperPosition? openPosition;
  final DemoPaperPendingOrder? pendingOrder;
  final DemoPaperDecisionSnapshot? decisionSnapshot;
  final List<DemoPaperTrade> tradeHistory;
  final DemoPaperStats stats;
  final DateTime? updatedAt;

  factory DemoPaperAccount.initial() {
    return const DemoPaperAccount(
      mode: 'paper',
      startingBalanceUsdt: 100,
      balanceUsdt: 100,
      leverage: 5,
      notionalPerTradeUsdt: 500,
      targetProfitPercent: 0.45,
      stopLossPercent: -0.7,
      maxHoldSeconds: 300,
      openPosition: null,
      pendingOrder: null,
      decisionSnapshot: null,
      tradeHistory: <DemoPaperTrade>[],
      stats: DemoPaperStats.empty(),
      updatedAt: null,
    );
  }

  factory DemoPaperAccount.fromMap(Map<String, dynamic> map) {
    final history = <DemoPaperTrade>[];
    final rawHistory = map['tradeHistory'];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map) {
          history.add(DemoPaperTrade.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawPosition = map['openPosition'];
    final rawPendingOrder = map['pendingOrder'];
    final rawDecisionSnapshot = map['decisionSnapshot'];
    final rawStats = map['stats'];

    return DemoPaperAccount(
      mode: map['mode']?.toString() ?? 'paper',
      startingBalanceUsdt: _doubleValue(map['startingBalanceUSDT'], 100),
      balanceUsdt: _doubleValue(map['balanceUSDT'], 100),
      leverage: _doubleValue(map['leverage'], 5),
      notionalPerTradeUsdt: _doubleValue(
        map['notionalPerTradeUSDT'],
        _doubleValue(map['balanceUSDT'], 100) *
            _doubleValue(map['leverage'], 5),
      ),
      targetProfitPercent: _doubleValue(map['targetProfitPercent'], 0.45),
      stopLossPercent: _doubleValue(map['stopLossPercent'], -0.7),
      maxHoldSeconds: _intValue(map['maxHoldSeconds'], 300),
      openPosition: rawPosition is Map
          ? DemoPaperPosition.fromMap(Map<String, dynamic>.from(rawPosition))
          : null,
      pendingOrder: rawPendingOrder is Map
          ? DemoPaperPendingOrder.fromMap(
              Map<String, dynamic>.from(rawPendingOrder),
            )
          : null,
      decisionSnapshot: rawDecisionSnapshot is Map
          ? DemoPaperDecisionSnapshot.fromMap(
              Map<String, dynamic>.from(rawDecisionSnapshot),
            )
          : null,
      tradeHistory: history,
      stats: rawStats is Map
          ? DemoPaperStats.fromMap(Map<String, dynamic>.from(rawStats))
          : const DemoPaperStats.empty(),
      updatedAt: _dateValue(map['updatedAt']),
    );
  }

  List<DemoPaperTrade> get closedTrades {
    return tradeHistory
        .where((trade) => trade.eventType == 'SELL')
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }
}

class DemoPaperDecisionSnapshot {
  const DemoPaperDecisionSnapshot({
    required this.evaluatedAt,
    required this.rankedSignalCount,
    required this.acceptedPlan,
    required this.topRejections,
  });

  final DateTime? evaluatedAt;
  final int rankedSignalCount;
  final DemoPaperDecisionPlan? acceptedPlan;
  final List<DemoPaperDecisionRejection> topRejections;

  factory DemoPaperDecisionSnapshot.fromMap(Map<String, dynamic> map) {
    final rawRejections = map['topRejections'];
    final rejections = <DemoPaperDecisionRejection>[];
    if (rawRejections is List) {
      for (final item in rawRejections) {
        if (item is Map) {
          rejections.add(
            DemoPaperDecisionRejection.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawAcceptedPlan = map['acceptedPlan'];

    return DemoPaperDecisionSnapshot(
      evaluatedAt: _dateValue(map['evaluatedAt']),
      rankedSignalCount: _intValue(map['rankedSignalCount']),
      acceptedPlan: rawAcceptedPlan is Map
          ? DemoPaperDecisionPlan.fromMap(
              Map<String, dynamic>.from(rawAcceptedPlan),
            )
          : null,
      topRejections: rejections,
    );
  }
}

class DemoPaperDecisionPlan {
  const DemoPaperDecisionPlan({
    required this.tokenName,
    required this.signalType,
    required this.strategy,
    required this.entryOrderType,
    required this.qualityScore,
    required this.currentPrice,
    required this.plannedLimitPrice,
    required this.targetProfitPercent,
    required this.stopLossPercent,
    required this.metrics,
  });

  final String tokenName;
  final String signalType;
  final String strategy;
  final String entryOrderType;
  final double qualityScore;
  final double currentPrice;
  final double plannedLimitPrice;
  final double targetProfitPercent;
  final double stopLossPercent;
  final DemoPaperDecisionMetrics metrics;

  factory DemoPaperDecisionPlan.fromMap(Map<String, dynamic> map) {
    final rawMetrics = map['metrics'];

    return DemoPaperDecisionPlan(
      tokenName: map['tokenName']?.toString() ?? '',
      signalType: map['signalType']?.toString() ?? '',
      strategy: map['strategy']?.toString() ?? '',
      entryOrderType: map['entryOrderType']?.toString() ?? '',
      qualityScore: _doubleValue(map['qualityScore']),
      currentPrice: _doubleValue(map['currentPrice']),
      plannedLimitPrice: _doubleValue(map['plannedLimitPrice']),
      targetProfitPercent: _doubleValue(map['targetProfitPercent']),
      stopLossPercent: _doubleValue(map['stopLossPercent']),
      metrics: rawMetrics is Map
          ? DemoPaperDecisionMetrics.fromMap(
              Map<String, dynamic>.from(rawMetrics),
            )
          : const DemoPaperDecisionMetrics.empty(),
    );
  }
}

class DemoPaperDecisionRejection {
  const DemoPaperDecisionRejection({
    required this.tokenName,
    required this.signalType,
    required this.score,
    required this.reason,
    required this.metrics,
  });

  final String tokenName;
  final String signalType;
  final double score;
  final String reason;
  final DemoPaperDecisionMetrics metrics;

  factory DemoPaperDecisionRejection.fromMap(Map<String, dynamic> map) {
    final rawMetrics = map['metrics'];

    return DemoPaperDecisionRejection(
      tokenName: map['tokenName']?.toString() ?? '',
      signalType: map['signalType']?.toString() ?? '',
      score: _doubleValue(map['score']),
      reason: map['reason']?.toString() ?? '',
      metrics: rawMetrics is Map
          ? DemoPaperDecisionMetrics.fromMap(
              Map<String, dynamic>.from(rawMetrics),
            )
          : const DemoPaperDecisionMetrics.empty(),
    );
  }
}

class DemoPaperDecisionMetrics {
  const DemoPaperDecisionMetrics({
    required this.rolling5m,
    required this.rolling15m,
    required this.rolling30m,
    required this.relativeVolume5m,
    required this.netVolume5m,
    required this.rsi3,
    required this.rsi14,
    required this.rsi50,
    required this.bollUpperRoom,
    required this.closeMinusEma7,
  });

  const DemoPaperDecisionMetrics.empty()
    : rolling5m = 0,
      rolling15m = 0,
      rolling30m = 0,
      relativeVolume5m = 0,
      netVolume5m = 0,
      rsi3 = 0,
      rsi14 = 0,
      rsi50 = 0,
      bollUpperRoom = 0,
      closeMinusEma7 = 0;

  final double rolling5m;
  final double rolling15m;
  final double rolling30m;
  final double relativeVolume5m;
  final double netVolume5m;
  final double rsi3;
  final double rsi14;
  final double rsi50;
  final double bollUpperRoom;
  final double closeMinusEma7;

  factory DemoPaperDecisionMetrics.fromMap(Map<String, dynamic> map) {
    return DemoPaperDecisionMetrics(
      rolling5m: _doubleValue(map['rolling5m']),
      rolling15m: _doubleValue(map['rolling15m']),
      rolling30m: _doubleValue(map['rolling30m']),
      relativeVolume5m: _doubleValue(map['relativeVolume5m']),
      netVolume5m: _doubleValue(map['netVolume5m']),
      rsi3: _doubleValue(map['rsi3']),
      rsi14: _doubleValue(map['rsi14']),
      rsi50: _doubleValue(map['rsi50']),
      bollUpperRoom: _doubleValue(map['bollUpperRoom']),
      closeMinusEma7: _doubleValue(map['closeMinusEma7']),
    );
  }
}

class DemoPaperPendingOrder {
  const DemoPaperPendingOrder({
    required this.symbol,
    required this.signalType,
    required this.entryStrategy,
    required this.plannedLimitPrice,
    required this.currentPrice,
    required this.limitDistancePercent,
    required this.qualityScore,
    required this.createdAt,
    required this.expiresAt,
  });

  final String symbol;
  final String signalType;
  final String entryStrategy;
  final double plannedLimitPrice;
  final double currentPrice;
  final double limitDistancePercent;
  final double qualityScore;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory DemoPaperPendingOrder.fromMap(Map<String, dynamic> map) {
    return DemoPaperPendingOrder(
      symbol: map['symbol']?.toString() ?? '',
      signalType: map['signalType']?.toString() ?? 'setup',
      entryStrategy:
          map['entryStrategy']?.toString() ?? 'EMA_PULLBACK_LIMIT_OCO',
      plannedLimitPrice: _doubleValue(map['plannedLimitPrice']),
      currentPrice: _doubleValue(
        map['currentPrice'],
        _doubleValue(map['currentPriceAtPlan']),
      ),
      limitDistancePercent: _doubleValue(map['limitDistancePercent']),
      qualityScore: _doubleValue(map['qualityScore']),
      createdAt: _dateValue(map['createdAt']),
      expiresAt: _dateValue(map['expiresAt']),
    );
  }
}

class DemoPaperPosition {
  const DemoPaperPosition({
    required this.symbol,
    required this.signalType,
    required this.signalScore,
    required this.entryPrice,
    required this.currentPrice,
    required this.entryTime,
    required this.marginUsdt,
    required this.notionalUsdt,
    required this.leverage,
    required this.unrealizedPriceChangePercent,
    required this.unrealizedPnlUsdt,
    required this.holdSeconds,
  });

  final String symbol;
  final String signalType;
  final double signalScore;
  final double entryPrice;
  final double currentPrice;
  final DateTime? entryTime;
  final double marginUsdt;
  final double notionalUsdt;
  final double leverage;
  final double unrealizedPriceChangePercent;
  final double unrealizedPnlUsdt;
  final int holdSeconds;

  factory DemoPaperPosition.fromMap(Map<String, dynamic> map) {
    return DemoPaperPosition(
      symbol: map['symbol']?.toString() ?? '',
      signalType: map['signalType']?.toString() ?? 'setup',
      signalScore: _doubleValue(map['signalScore']),
      entryPrice: _doubleValue(map['entryPrice']),
      currentPrice: _doubleValue(
        map['currentPrice'],
        _doubleValue(map['entryPrice']),
      ),
      entryTime: _dateValue(map['entryTime']),
      marginUsdt: _doubleValue(map['marginUSDT']),
      notionalUsdt: _doubleValue(map['notionalUSDT']),
      leverage: _doubleValue(map['leverage'], 5),
      unrealizedPriceChangePercent: _doubleValue(
        map['unrealizedPriceChangePercent'],
      ),
      unrealizedPnlUsdt: _doubleValue(map['unrealizedPnlUSDT']),
      holdSeconds: _intValue(map['holdSeconds']),
    );
  }
}

class DemoPaperTrade {
  const DemoPaperTrade({
    required this.eventType,
    required this.symbol,
    required this.result,
    required this.entryPrice,
    required this.exitPrice,
    required this.priceChangePercent,
    required this.profitLossUsdt,
    required this.profitLossPercentOnMargin,
    required this.closedAt,
    required this.exitReason,
    required this.leverage,
  });

  final String eventType;
  final String symbol;
  final String result;
  final double entryPrice;
  final double exitPrice;
  final double priceChangePercent;
  final double profitLossUsdt;
  final double profitLossPercentOnMargin;
  final DateTime? closedAt;
  final String exitReason;
  final double leverage;

  factory DemoPaperTrade.fromMap(Map<String, dynamic> map) {
    return DemoPaperTrade(
      eventType: map['eventType']?.toString() ?? '',
      symbol: map['symbol']?.toString() ?? '',
      result: map['result']?.toString() ?? '',
      entryPrice: _doubleValue(map['entryPrice']),
      exitPrice: _doubleValue(map['exitPrice']),
      priceChangePercent: _doubleValue(map['priceChangePercent']),
      profitLossUsdt: _doubleValue(map['profitLossUSDT']),
      profitLossPercentOnMargin: _doubleValue(map['profitLossPercentOnMargin']),
      closedAt: _dateValue(map['closedAt']),
      exitReason: map['exitReason']?.toString() ?? '',
      leverage: _doubleValue(map['leverage'], 5),
    );
  }
}

class DemoPaperStats {
  const DemoPaperStats({
    required this.totalClosedTrades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.realizedPnlUsdt,
    required this.realizedPnlPercent,
  });

  const DemoPaperStats.empty()
    : totalClosedTrades = 0,
      wins = 0,
      losses = 0,
      winRate = 0,
      realizedPnlUsdt = 0,
      realizedPnlPercent = 0;

  final int totalClosedTrades;
  final int wins;
  final int losses;
  final double winRate;
  final double realizedPnlUsdt;
  final double realizedPnlPercent;

  factory DemoPaperStats.fromMap(Map<String, dynamic> map) {
    return DemoPaperStats(
      totalClosedTrades: _intValue(map['totalClosedTrades']),
      wins: _intValue(map['wins']),
      losses: _intValue(map['losses']),
      winRate: _doubleValue(map['winRate']),
      realizedPnlUsdt: _doubleValue(map['realizedPnlUSDT']),
      realizedPnlPercent: _doubleValue(map['realizedPnlPercent']),
    );
  }
}

double _doubleValue(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _intValue(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _dateValue(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
