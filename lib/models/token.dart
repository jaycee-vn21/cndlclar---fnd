class Token {
  final String name;
  final double price;
  final double change1d;
  final double changeSelectedInterval;
  final double? volume;
  final double? marketCap;

  Token({
    required this.name,
    required this.price,
    required this.change1d,
    required this.changeSelectedInterval,
    this.volume,
    this.marketCap,
  });

  factory Token.fromMap(Map<String, dynamic> map) {
    return Token(
      name: map["name"],
      price: map["price"].toDouble(),
      change1d: map["change1d"].toDouble(),
      changeSelectedInterval: map["changeSelectedInterval"].toDouble(),
      volume: map["volume"]?.toDouble(),
      marketCap: map["marketCap"]?.toDouble(),
    );
  }
}
