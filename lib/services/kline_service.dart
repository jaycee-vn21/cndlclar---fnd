import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/kline_data.dart';

class KlineService {
  final String baseUrl;

  KlineService({required this.baseUrl});

  /// Fetch historical Klines for a symbol + interval
  Future<List<KlineData>> fetchHistoricalKlines({
    required String symbol,
    required String interval,
    int limit = 500,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/v1/data/kline/historical?symbol=$symbol&interval=$interval&limit=$limit',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      // print('no restAPI for: $symbol');
      // throw Exception('Failed to fetch historical Klines');
      return [];
    }

    final Map<String, dynamic> jsonData = jsonDecode(response.body);
    final List<dynamic> candlesJson = jsonData['data'];

    return candlesJson.map((e) => KlineData.fromJson(e)).toList();
  }
}
