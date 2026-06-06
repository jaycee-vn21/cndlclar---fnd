class KlineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double volumeUsdt;
  final double netVolumeUsdt;
  final bool isClosed;

  double? ema9;
  double? ema21;

  KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    double? volumeUsdt,
    this.netVolumeUsdt = 0,
    this.isClosed = false,
    this.ema9,
    this.ema21,
  }) : volumeUsdt = volumeUsdt ?? volume;

  factory KlineData.fromJson(Map<String, dynamic> json) {
    final volumeUsdt =
        (json['volumeUsdt'] ??
                json['volumeInMoney'] ??
                json['volumeInMoneyInInterval'] ??
                json['volume'] ??
                0)
            as num;
    final netVolumeUsdt =
        (json['netVolumeUsdt'] ??
                json['netVolumeInMoney'] ??
                json['netVolumeInMoneyInInterval'] ??
                json['netVolume'] ??
                0)
            as num;

    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(json['time']),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: volumeUsdt.toDouble(),
      volumeUsdt: volumeUsdt.toDouble(),
      netVolumeUsdt: netVolumeUsdt.toDouble(),
      isClosed: (json['isClosed'] as bool?) ?? true,
    );
  }
}
