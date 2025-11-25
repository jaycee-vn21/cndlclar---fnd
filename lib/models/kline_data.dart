class KlineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  double? ema9;
  double? ema21;

  KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.ema9,
    this.ema21,
  });

  factory KlineData.fromJson(Map<String, dynamic> json) {
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(json['time']),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
    );
  }
}
