import 'package:cndlclar/models/indicator.dart';

class Token {
  final String name;
  final double marketCap;
  List<Indicator> indicators;

  // Interval-based numeric properties
  final Map<String, double> closePricePerInterval;
  final Map<String, double> priceChangePercentPerInterval;
  final Map<String, double> volumePerInterval;
  final Map<String, DateTime> intervalStartTimes;

  // Sparkline per interval (dummy generated externally)
  final Map<String, List<double>> sparklineData;
  final Map<String, List<double>> sparklineDataOriginal;

  Token({
    required this.name,
    required this.marketCap,
    required this.indicators,
    required this.closePricePerInterval,
    required this.priceChangePercentPerInterval,
    required this.volumePerInterval,
    required this.intervalStartTimes,
    required this.sparklineData,
    required this.sparklineDataOriginal,
  });

  factory Token.fromMap(Map<String, dynamic> map) {
    final priceChangePercentPerInterval = <String, double>{};
    final volumePerInterval = <String, double>{};
    final closePricePerInterval = <String, double>{};
    final intervalStartTimes = <String, DateTime>{};

    // Empty sparkline placeholders (will be filled in TokensProvider)
    final sparklineData = <String, List<double>>{};
    final sparklineDataOriginal = <String, List<double>>{};

    map.forEach((key, value) {
      if (key.startsWith('priceChangePercent')) {
        final interval = key.replaceFirst('priceChangePercent', '');
        priceChangePercentPerInterval[interval] = (value ?? 0).toDouble();
      } else if (key.startsWith('volumeInMoney')) {
        final interval = key.replaceFirst('volumeInMoney', '');
        volumePerInterval[interval] = (value ?? 0).toDouble();
      } else if (key.startsWith('closePrice')) {
        final interval = key.replaceFirst('closePrice', '');
        closePricePerInterval[interval] = (value ?? 0).toDouble();

        // Sparkline will be injected later
        sparklineData[interval] = [];
        sparklineDataOriginal[interval] = [];
      } else if (key.startsWith('intervalStartTime')) {
        final interval = key.replaceFirst('intervalStartTime', '');
        if (value != null) {
          final dt = DateTime.tryParse(value.toString());
          if (dt != null) {
            intervalStartTimes[interval] = dt;
          }
        }
      }
    });

    return Token(
      name: map['tokenName'] ?? '',
      marketCap: (map['marketCap'] ?? 0).toDouble(),
      indicators: [], // will be set in provider
      closePricePerInterval: closePricePerInterval,
      priceChangePercentPerInterval: priceChangePercentPerInterval,
      volumePerInterval: volumePerInterval,
      intervalStartTimes: intervalStartTimes,
      sparklineData: sparklineData,
      sparklineDataOriginal: sparklineDataOriginal,
    );
  }

  // -------------------
  // Helper getters
  // -------------------
  double closePrice(String interval) => closePricePerInterval[interval] ?? 0;
  double priceChange(String interval) =>
      priceChangePercentPerInterval[interval] ?? 0;
  double volume(String interval) => volumePerInterval[interval] ?? 0;
  DateTime? startTime(String interval) => intervalStartTimes[interval];
  List<double> sparkline(String interval) =>
      sparklineData[interval] ?? <double>[];
  List<double> sparklineOriginal(String interval) =>
      sparklineDataOriginal[interval] ?? <double>[];
}
