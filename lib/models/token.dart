class Token {
  final String name;
  final double price;
  final double change1d;
  final double changeSelectedInterval;
  final double? volume; // dummy volume
  final double? marketCap; // dummy market cap

  Token({
    required this.name,
    required this.price,
    required this.change1d,
    required this.changeSelectedInterval,
    this.volume,
    this.marketCap,
  });

  factory Token.fromJson(Map<String, dynamic> json, String selectedInterval) {
    return Token(
      name: json['symbol'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      change1d: (json['change_1d'] ?? 0).toDouble(),
      changeSelectedInterval: (json['change_$selectedInterval'] ?? 0)
          .toDouble(),
      volume: (json['volume'] ?? 0).toDouble(),
      marketCap: (json['marketCap'] ?? 0).toDouble(),
    );
  }
}
