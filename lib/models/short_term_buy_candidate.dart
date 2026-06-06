class ShortTermBuyCandidate {
  const ShortTermBuyCandidate({
    required this.rank,
    required this.tokenName,
    required this.score,
    required this.reasons,
    required this.metrics,
  });

  final int rank;
  final String tokenName;
  final double score;
  final List<String> reasons;
  final Map<String, double?> metrics;

  factory ShortTermBuyCandidate.fromMap(Map<String, dynamic> map) {
    final rawMetrics = map['metrics'];
    final parsedMetrics = <String, double?>{};

    if (rawMetrics is Map) {
      rawMetrics.forEach((key, value) {
        parsedMetrics[key.toString()] = _nullableDouble(value);
      });
    }

    return ShortTermBuyCandidate(
      rank: _intValue(map['rank']),
      tokenName: map['tokenName']?.toString() ?? '',
      score: _doubleValue(map['score']),
      reasons: _stringList(map['reasons']),
      metrics: parsedMetrics,
    );
  }

  double? metric(String key) => metrics[key];

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(dynamic value) => _nullableDouble(value) ?? 0;

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    return parsed == null || parsed.isNaN || parsed.isInfinite ? null : parsed;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
