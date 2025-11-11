import 'package:flutter/material.dart';

class SortingFieldProvider extends ChangeNotifier {
  String _sortingField = 'priceChange';

  String get sortingField => _sortingField;

  void setSortingField(String newField) {
    if (_sortingField != newField) {
      _sortingField = newField;
      notifyListeners();
    }
  }
}
