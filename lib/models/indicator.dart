import 'package:flutter/material.dart';

// ---------- Example Backend Response (per token) -------
// {
//   "name": "BTC",
//   "price": 30000,
//   "change1d": 1.2,
//   "changeSelectedInterval": 0.5,
//   "volume": 45000000000,
//   "marketCap": 550000000000,
//   "indicators": [
//     { "key": "ema", "label": "EMA 9/21", "value": "29.5/28.7", "bullish": true },
//     { "key": "rsi", "label": "RSI", "value": "72", "bullish": false },
//     { "key": "macd", "label": "MACD", "value": "0.13", "bullish": true }
//   ]
// }

class Indicator {
  final String key; // e.g., "ema", "rsi", "macd"
  final String label; // e.g., "EMA 9/21", "EMA 21/50"
  final String value; // formatted value
  final bool bullish;
  final IconData icon;

  const Indicator({
    required this.key,
    required this.label,
    required this.value,
    required this.bullish,
    required this.icon,
  });

  /// -----------------------------
  /// Backend creation
  /// -----------------------------
  factory Indicator.fromMap(Map<String, dynamic> map) {
    // Use backend-provided label if exists, otherwise default
    final key = map['key']?.toString() ?? 'unknown';
    final rawLabel = map['label']?.toString();
    final rawValue = map['value'];
    final bullish = map['bullish'] ?? true;

    return Indicator(
      key: key,
      label: rawLabel ?? _defaultLabelForKey(key),
      value: _formatValue(rawValue),
      bullish: bullish,
      icon: _iconForKey(key),
    );
  }

  /// -----------------------------
  /// Dummy/testing creation
  /// -----------------------------
  factory Indicator.fromKey({
    required String key,
    required dynamic rawValue,
    required bool bullish,
    String? label, // optional label for multiple EMA, etc.
  }) {
    return Indicator(
      key: key,
      label: label ?? _defaultLabelForKey(key),
      value: _formatValue(rawValue),
      bullish: bullish,
      icon: _iconForKey(key),
    );
  }

  /// Icon mapping by key
  static IconData _iconForKey(String key) {
    switch (key.toLowerCase()) {
      case 'ema':
        return Icons.trending_up;
      case 'rsi':
        return Icons.show_chart;
      case 'macd':
        return Icons.multiline_chart;
      case 'stoch':
        return Icons.stacked_line_chart;
      default:
        return Icons.trending_up;
    }
  }

  /// Default label mapping (only fallback)
  static String _defaultLabelForKey(String key) {
    switch (key.toLowerCase()) {
      case 'ema':
        return 'EMA'; // now generic, backend can override
      case 'rsi':
        return 'RSI';
      case 'macd':
        return 'MACD';
      case 'stoch':
        return 'Stoch';
      default:
        return key.toUpperCase();
    }
  }

  /// Format numeric or string value
  static String _formatValue(dynamic rawValue) {
    if (rawValue == null) return '-';
    if (rawValue is num) return rawValue.toStringAsFixed(2);
    return rawValue.toString();
  }
}
