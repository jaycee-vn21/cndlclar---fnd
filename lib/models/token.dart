import 'package:cndlclar/models/indicator.dart';

class Token {
  final String name;
  final double marketCap;
  List<Indicator> indicators;
  final double tickerPriceChange1h;
  final Map<String, double> rollingPriceChangePerInterval;
  final Map<String, bool> rollingPriceChangeReadyPerInterval;

  // Interval-based numeric properties
  final Map<String, double> openPricePerInterval;
  final Map<String, double> closePricePerInterval;
  final Map<String, double> highPricePerInterval;
  final Map<String, double> lowPricePerInterval;
  final Map<String, double> priceChangePercentPerInterval;
  final Map<String, double> volumePerInterval;
  final Map<String, double> netVolumePerInterval;
  final Map<String, DateTime> intervalStartTimes;
  final Map<String, bool> intervalClosedPerInterval;

  // Sparkline per interval (dummy generated externally)
  final Map<String, List<double>> sparklineData;
  final Map<String, List<double>> sparklineDataOriginal;

  Token({
    required this.name,
    required this.marketCap,
    required this.indicators,
    required this.tickerPriceChange1h,
    required this.rollingPriceChangePerInterval,
    required this.rollingPriceChangeReadyPerInterval,
    required this.openPricePerInterval,
    required this.closePricePerInterval,
    required this.highPricePerInterval,
    required this.lowPricePerInterval,
    required this.priceChangePercentPerInterval,
    required this.volumePerInterval,
    required this.netVolumePerInterval,
    required this.intervalStartTimes,
    required this.intervalClosedPerInterval,
    required this.sparklineData,
    required this.sparklineDataOriginal,
  });

  factory Token.fromMap(Map<String, dynamic> map) {
    final priceChangePercentPerInterval = <String, double>{};
    final volumePerInterval = <String, double>{};
    final netVolumePerInterval = <String, double>{};
    final openPricePerInterval = <String, double>{};
    final closePricePerInterval = <String, double>{};
    final highPricePerInterval = <String, double>{};
    final lowPricePerInterval = <String, double>{};
    final intervalStartTimes = <String, DateTime>{};
    final intervalClosedPerInterval = <String, bool>{};
    final rollingPriceChangePerInterval = <String, double>{};
    final rollingPriceChangeReadyPerInterval = <String, bool>{};

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
      } else if (key.startsWith('netVolumeInMoney')) {
        final interval = key.replaceFirst('netVolumeInMoney', '');
        netVolumePerInterval[interval] = (value ?? 0).toDouble();
      } else if (key.startsWith('openPrice')) {
        final interval = key.replaceFirst('openPrice', '');
        openPricePerInterval[interval] = (value ?? 0).toDouble();
      } else if (key.startsWith('closePrice')) {
        final interval = key.replaceFirst('closePrice', '');
        closePricePerInterval[interval] = (value ?? 0).toDouble();

        // Sparkline will be injected later
        sparklineData[interval] = [];
        sparklineDataOriginal[interval] = [];
      } else if (key.startsWith('highPrice')) {
        final interval = key.replaceFirst('highPrice', '');
        highPricePerInterval[interval] = (value ?? 0).toDouble();
      } else if (key.startsWith('lowPrice')) {
        final interval = key.replaceFirst('lowPrice', '');
        lowPricePerInterval[interval] = (value ?? 0).toDouble();
      } else if (key.startsWith('intervalStartTime')) {
        final interval = key.replaceFirst('intervalStartTime', '');
        if (value != null) {
          final dt = DateTime.tryParse(value.toString());
          if (dt != null) {
            intervalStartTimes[interval] = dt;
          }
        }
      } else if (key.startsWith('isIntervalClosed')) {
        final interval = key.replaceFirst('isIntervalClosed', '');
        intervalClosedPerInterval[interval] = value == true;
      } else if (key.startsWith('rollingPriceChangeReady')) {
        final interval = key.replaceFirst('rollingPriceChangeReady', '');
        rollingPriceChangeReadyPerInterval[interval] = value == true;
      } else if (key.startsWith('rollingPriceChange')) {
        final interval = key.replaceFirst('rollingPriceChange', '');
        if (value is num) {
          rollingPriceChangePerInterval[interval] = value.toDouble();
        }
      }
    });

    final tickerPriceChange1h =
        (map['tickerPriceChange1h'] ?? map['rollingPriceChange1h'] ?? 0)
            .toDouble();
    rollingPriceChangePerInterval.putIfAbsent('1h', () => tickerPriceChange1h);
    rollingPriceChangeReadyPerInterval.putIfAbsent(
      '1h',
      () => map['rollingPriceChangeReady1h'] != false,
    );

    return Token(
      name: map['tokenName'] ?? '',
      marketCap: (map['marketCap'] ?? 0).toDouble(),
      indicators: [], // will be set in provider
      tickerPriceChange1h: tickerPriceChange1h,
      rollingPriceChangePerInterval: rollingPriceChangePerInterval,
      rollingPriceChangeReadyPerInterval: rollingPriceChangeReadyPerInterval,
      openPricePerInterval: openPricePerInterval,
      closePricePerInterval: closePricePerInterval,
      highPricePerInterval: highPricePerInterval,
      lowPricePerInterval: lowPricePerInterval,
      priceChangePercentPerInterval: priceChangePercentPerInterval,
      volumePerInterval: volumePerInterval,
      netVolumePerInterval: netVolumePerInterval,
      intervalStartTimes: intervalStartTimes,
      intervalClosedPerInterval: intervalClosedPerInterval,
      sparklineData: sparklineData,
      sparklineDataOriginal: sparklineDataOriginal,
    );
  }

  // -------------------
  // Helper getters
  // -------------------
  double openPrice(String interval) => openPricePerInterval[interval] ?? 0;
  double closePrice(String interval) => closePricePerInterval[interval] ?? 0;
  double highPrice(String interval) => highPricePerInterval[interval] ?? 0;
  double lowPrice(String interval) => lowPricePerInterval[interval] ?? 0;
  double priceChange(String interval) =>
      priceChangePercentPerInterval[interval] ?? 0;
  double volume(String interval) => volumePerInterval[interval] ?? 0;
  double netVolume(String interval) => netVolumePerInterval[interval] ?? 0;
  double rollingPriceChange(String interval) =>
      rollingPriceChangePerInterval[interval] ??
      (interval == '1h' ? tickerPriceChange1h : 0);
  bool hasRollingPriceChange(String interval) =>
      rollingPriceChangeReadyPerInterval[interval] ??
      rollingPriceChangePerInterval.containsKey(interval);
  DateTime? startTime(String interval) => intervalStartTimes[interval];
  bool isIntervalClosed(String interval) =>
      intervalClosedPerInterval[interval] ?? false;
  List<double> sparkline(String interval) =>
      sparklineData[interval] ?? <double>[];
  List<double> sparklineOriginal(String interval) =>
      sparklineDataOriginal[interval] ?? <double>[];
}
