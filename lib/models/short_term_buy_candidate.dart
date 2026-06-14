class ShortTermSignalTrack {
  const ShortTermSignalTrack({
    required this.type,
    required this.score,
    required this.isActive,
    required this.rank,
    required this.reasons,
  });

  final String type;
  final double score;
  final bool isActive;
  final int? rank;
  final List<String> reasons;

  factory ShortTermSignalTrack.fromMap(
    dynamic value, {
    required String type,
    required double fallbackScore,
    required bool fallbackIsActive,
    required int? fallbackRank,
    required List<String> fallbackReasons,
  }) {
    if (value is! Map) {
      return ShortTermSignalTrack(
        type: type,
        score: fallbackScore,
        isActive: fallbackIsActive,
        rank: fallbackRank,
        reasons: fallbackReasons,
      );
    }

    final map = Map<String, dynamic>.from(value);
    final parsedReasons = ShortTermBuyCandidate._stringList(map['reasons']);
    return ShortTermSignalTrack(
      type: map['type']?.toString() ?? type,
      score: map.containsKey('score')
          ? ShortTermBuyCandidate._doubleValue(map['score'])
          : fallbackScore,
      isActive:
          ShortTermBuyCandidate._boolValue(map['isActive']) ?? fallbackIsActive,
      rank: ShortTermBuyCandidate._nullableInt(map['rank']) ?? fallbackRank,
      reasons: parsedReasons.isNotEmpty ? parsedReasons : fallbackReasons,
    );
  }
}

class ShortTermBuyCandidate {
  const ShortTermBuyCandidate({
    required this.rank,
    required this.tokenName,
    required this.score,
    required this.reasons,
    required this.metrics,
    required this.primarySignalType,
    required this.signalTypes,
    required this.setupSignal,
    required this.elasticSignal,
    required this.structureSignal,
  });

  final int rank;
  final String tokenName;
  final double score;
  final List<String> reasons;
  final Map<String, double?> metrics;
  final String primarySignalType;
  final List<String> signalTypes;
  final ShortTermSignalTrack setupSignal;
  final ShortTermSignalTrack elasticSignal;
  final ShortTermSignalTrack structureSignal;

  factory ShortTermBuyCandidate.fromMap(Map<String, dynamic> map) {
    final rawMetrics = map['metrics'];
    final parsedMetrics = <String, double?>{};

    if (rawMetrics is Map) {
      rawMetrics.forEach((key, value) {
        parsedMetrics[key.toString()] = _nullableDouble(value);
      });
    }

    final rawSignals = map['signals'];
    final signals = rawSignals is Map
        ? Map<String, dynamic>.from(rawSignals)
        : const <String, dynamic>{};
    final topLevelReasons = _stringList(map['reasons']);
    final setupFallbackScore = _doubleValue(map['setupScore'] ?? map['score']);
    final elasticFallbackScore = _doubleValue(map['elasticScore']);
    final setupSignal = ShortTermSignalTrack.fromMap(
      signals['setup'],
      type: 'setup',
      fallbackScore: setupFallbackScore,
      fallbackIsActive:
          _boolValue(map['setupActive']) ??
          (signals.isEmpty && setupFallbackScore > 0),
      fallbackRank:
          _nullableInt(map['setupRank']) ??
          (signals.isEmpty ? _nullableInt(map['rank']) : null),
      fallbackReasons: _stringList(map['setupReasons']).isNotEmpty
          ? _stringList(map['setupReasons'])
          : topLevelReasons,
    );
    final elasticSignal = ShortTermSignalTrack.fromMap(
      signals['elastic'],
      type: 'elastic',
      fallbackScore: elasticFallbackScore,
      fallbackIsActive: _boolValue(map['elasticActive']) ?? false,
      fallbackRank: _nullableInt(map['elasticRank']),
      fallbackReasons: _stringList(map['elasticReasons']),
    );
    final structureFallbackScore = _doubleValue(map['structureScore']);
    final structureSignal = ShortTermSignalTrack.fromMap(
      signals['structure'],
      type: 'structure',
      fallbackScore: structureFallbackScore,
      fallbackIsActive: _boolValue(map['structureActive']) ?? false,
      fallbackRank: _nullableInt(map['structureRank']),
      fallbackReasons: _stringList(map['structureReasons']),
    );
    final primaryType = _primaryType(
      map['primarySignalType'],
      setupSignal,
      elasticSignal,
      structureSignal,
    );
    final primaryReasons = primaryType == 'elastic'
        ? elasticSignal.reasons
        : primaryType == 'structure'
        ? structureSignal.reasons
        : setupSignal.reasons;
    final parsedSignalTypes = _stringList(map['signalTypes']);
    final parsedScore = _doubleValue(map['score']);
    final fallbackScore = [
      setupSignal.score,
      elasticSignal.score,
      structureSignal.score,
    ].reduce((a, b) => a > b ? a : b);

    return ShortTermBuyCandidate(
      rank: _intValue(map['rank']),
      tokenName: map['tokenName']?.toString() ?? '',
      score: map.containsKey('score') ? parsedScore : fallbackScore,
      reasons: topLevelReasons.isNotEmpty ? topLevelReasons : primaryReasons,
      metrics: parsedMetrics,
      primarySignalType: primaryType,
      signalTypes: parsedSignalTypes.isNotEmpty
          ? parsedSignalTypes
          : [
              if (setupSignal.isActive) 'setup',
              if (elasticSignal.isActive) 'elastic',
              if (structureSignal.isActive) 'structure',
            ],
      setupSignal: setupSignal,
      elasticSignal: elasticSignal,
      structureSignal: structureSignal,
    );
  }

  double? metric(String key) => metrics[key];

  double get setupScore => setupSignal.score;
  double get elasticScore => elasticSignal.score;
  double get structureScore => structureSignal.score;
  int? get setupRank => setupSignal.rank;
  int? get elasticRank => elasticSignal.rank;
  int? get structureRank => structureSignal.rank;
  bool get hasSetupSignal => setupSignal.isActive;
  bool get hasElasticSignal => elasticSignal.isActive;
  bool get hasStructureSignal => structureSignal.isActive;

  ShortTermSignalTrack get primarySignal => primarySignalType == 'elastic'
      ? elasticSignal
      : primarySignalType == 'structure'
      ? structureSignal
      : setupSignal;

  List<ShortTermSignalTrack> get activeSignals {
    final primary = primarySignal;
    final remaining = [setupSignal, elasticSignal, structureSignal]
        .where((signal) => signal.type != primary.type && signal.isActive)
        .toList(growable: false);

    return [if (primary.isActive) primary, ...remaining];
  }

  static int _intValue(dynamic value) {
    return _nullableInt(value) ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _doubleValue(dynamic value) => _nullableDouble(value) ?? 0;

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    return parsed == null || parsed.isNaN || parsed.isInfinite ? null : parsed;
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final stringValue = value?.toString().toLowerCase();
    if (stringValue == 'true') return true;
    if (stringValue == 'false') return false;
    return null;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static String _primaryType(
    dynamic value,
    ShortTermSignalTrack setupSignal,
    ShortTermSignalTrack elasticSignal,
    ShortTermSignalTrack structureSignal,
  ) {
    final parsed = value?.toString();
    if (parsed == 'setup' || parsed == 'elastic' || parsed == 'structure') {
      return parsed!;
    }

    final activeSignals =
        [
            setupSignal,
            elasticSignal,
            structureSignal,
          ].where((signal) => signal.isActive).toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    return activeSignals.isEmpty ? 'setup' : activeSignals.first.type;
  }
}
