import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cndlclar/utils/config.dart';

class TradeService {
  final String _baseUrl = '${AppConfig.baseV1Url}/trade';

  Future<Map<String, dynamic>> executeTrade({
    required String action, // "buy" or "sell"
    required String symbol,
    bool demoMode = false,
    int? requestedLeverage,
    double? currentPrice,
    double? priceToBuy,
    double? stopLossPercent,
    double? takeProfitPercent,
    double? baseAmount,
    double? autoSellProfitPercent,
    String? interval,
  }) async {
    final url = Uri.parse(
      demoMode ? '$_baseUrl/demo/$action' : '$_baseUrl/$action',
    );

    final headers = {
      'Content-Type': 'application/json',
      'x-device-token': AppConfig.deviceToken,
    };

    final payload = <String, dynamic>{
      'symbol': symbol,
      'requestedLeverage': requestedLeverage,
      'currentPrice': currentPrice,
      'priceToBuy': priceToBuy,
      'stopLossPercent': stopLossPercent,
      'takeProfitPercent': takeProfitPercent,
      'baseAmount': baseAmount,
      'autoSellProfitPercent': autoSellProfitPercent,
      'interval': interval,
    }..removeWhere((_, value) => value == null);

    final body = jsonEncode(payload);

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {'success': true, 'data': decoded};
      } else {
        final decoded = jsonDecode(response.body);
        return {
          'success': false,
          'error': decoded['message'] ?? 'Trade failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
