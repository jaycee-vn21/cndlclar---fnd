import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cndlclar/utils/config.dart';

class RealTradeAccountService {
  const RealTradeAccountService({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>?> fetchRealTradeAccount() async {
    final url = Uri.parse('$baseUrl/api/v1/data/real-account');

    try {
      final response = await http
          .get(url, headers: {'x-device-token': AppConfig.deviceToken})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final data = decoded['data'];
      if (data is! Map) return null;

      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }
}
