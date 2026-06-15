import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cndlclar/utils/config.dart';

class RealTradeAccountService {
  const RealTradeAccountService({required this.baseUrl});

  final String baseUrl;

  Map<String, dynamic> _errorSnapshot(String message) {
    return {
      'mode': 'real',
      'updatedAt': DateTime.now().toIso8601String(),
      'binanceAvailable': false,
      'balance': null,
      'openPositions': [],
      'activeStrategies': [],
      'openOrders': [],
      'tradeHistory': [],
      'stats': {'totalHistoryItems': 0, 'realizedPnlUSDT': 0},
      'error': message,
    };
  }

  Future<Map<String, dynamic>?> fetchRealTradeAccount() async {
    final url = Uri.parse('$baseUrl/api/v1/data/real-account');

    try {
      final response = await http
          .get(url, headers: {'x-device-token': AppConfig.deviceToken})
          .timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return _errorSnapshot('Real account returned an invalid response.');
      }

      if (response.statusCode != 200) {
        return _errorSnapshot(
          decoded['message']?.toString() ??
              'Real account request failed with HTTP ${response.statusCode}.',
        );
      }

      final data = decoded['data'];
      if (data is! Map) {
        return _errorSnapshot('Real account response is missing data.');
      }

      return Map<String, dynamic>.from(data);
    } catch (error) {
      return _errorSnapshot('Real account request failed: $error');
    }
  }
}
