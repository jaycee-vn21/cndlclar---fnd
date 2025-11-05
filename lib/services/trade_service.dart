import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cndlclar/utils/config.dart';

class TradeService {
  final String _baseUrl = '${AppConfig.baseV1Url}/trade';

  Future<Map<String, dynamic>> executeTrade({
    required String action, // "buy" or "sell"
    required String symbol,
    int? requestedLeverage,
    double? priceToBuy,
    double? stopLossPercent,
    double? takeProfitPercent,
    double? baseAmount,
  }) async {
    final url = Uri.parse('$_baseUrl/$action');

    final headers = {
      'Content-Type': 'application/json',
      'x-device-token': AppConfig.deviceToken,
    };

    final body = jsonEncode({
      'symbol': symbol,
      if (requestedLeverage != null) 'requestedLeverage': requestedLeverage,
      if (priceToBuy != null) 'priceToBuy': priceToBuy,
      if (stopLossPercent != null) 'stopLossPercent': stopLossPercent,
      if (takeProfitPercent != null) 'takeProfitPercent': takeProfitPercent,
      if (baseAmount != null) 'baseAmount': baseAmount,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
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
