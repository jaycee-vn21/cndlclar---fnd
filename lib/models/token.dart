import 'indicator.dart';

class Token {
  final String name;
  final double price;
  final double change1d;
  final double changeSelectedInterval;
  final double? volume;
  final double? marketCap;
  final List<Indicator> indicators;

  Token({
    required this.name,
    required this.price,
    required this.change1d,
    required this.changeSelectedInterval,
    this.volume,
    this.marketCap,
    required this.indicators,
  });

  factory Token.fromMap(Map<String, dynamic> map) {
    final rawIndicators = map['indicators'] as List<dynamic>? ?? [];

    return Token(
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      change1d: (map['change1d'] as num?)?.toDouble() ?? 0.0,
      changeSelectedInterval:
          (map['changeSelectedInterval'] as num?)?.toDouble() ?? 0.0,
      volume: map['volume'] != null ? (map['volume'] as num).toDouble() : null,
      marketCap: map['marketCap'] != null
          ? (map['marketCap'] as num).toDouble()
          : null,
      indicators: rawIndicators
          .map((e) => Indicator.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
