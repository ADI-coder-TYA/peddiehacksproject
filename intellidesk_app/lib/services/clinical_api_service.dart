import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ClinicalApiService {
  static Future<Map<String, dynamic>> submitClaim(Map<String, dynamic> payload) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/intake-web');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTelemetry() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/telemetry');
    final res = await http.get(uri);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getTickets() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/tickets');
    final res = await http.get(uri);
    return jsonDecode(res.body) as List<dynamic>;
  }
}
