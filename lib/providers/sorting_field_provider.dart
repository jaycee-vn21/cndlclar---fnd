import 'package:flutter/material.dart';

class SortingFields {
  static const priceChange = 'priceChange';
  static const tickerPriceChange1h = 'tickerPriceChange1h';
  static const rollingPriceChange5m = 'rollingPriceChange5m';
  static const rollingPriceChange15m = 'rollingPriceChange15m';
  static const rollingPriceChange30m = 'rollingPriceChange30m';
  static const rollingPriceChange1h = 'rollingPriceChange1h';
  static const signalScore = 'signalScore';
  static const setupSignalScore = 'setupSignalScore';
  static const elasticSignalScore = 'elasticSignalScore';
  static const structureSignalScore = 'structureSignalScore';
  static const rsiRebound = 'rsiRebound';
  static const volume = 'volume';
  static const relativeVolume5m = 'relativeVolume5m';
  static const ema7Setup = 'ema7Setup';
}

class SortingFieldProvider extends ChangeNotifier {
  String _sortingField = SortingFields.priceChange;

  String get sortingField => _sortingField;

  void setSortingField(String newField) {
    if (_sortingField != newField) {
      _sortingField = newField;
      notifyListeners();
    }
  }
}
