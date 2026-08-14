import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';

class ApiService extends ChangeNotifier {
  String get baseUrl => ApiConfig.baseUrl;
  
  List<dynamic> _cases = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  List<dynamic> get cases => _cases;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  Future<void> sendIntakeMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/intake'),
        headers: {
          'Content-Type': 'application/json',
          'x-institution-id': ApiConfig.institutionId,
        },
        body: jsonEncode({
          'studentName': 'Alex Student',
          'studentContact': 'alex@example.edu',
          'message': message,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('Error sending intake: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception sending intake: $e');
    }
  }

  Future<void> fetchCases() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/tickets'),
        headers: ApiConfig.adminAuthHeaders,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _cases = decoded;
        } else if (decoded is Map<String, dynamic>) {
          final List<dynamic> allCases = [];
          decoded.forEach((key, value) {
            if (value is List) {
              allCases.addAll(value);
            }
          });
          _cases = allCases;
        } else {
          _cases = [];
        }
      } else {
        _hasError = true;
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Network error: $e';
      debugPrint('Exception fetching cases: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCaseStatus(String id, String action) async {
    // action should be 'approve' or 'deny'
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/tickets/$id/$action'),
        headers: ApiConfig.adminHeaders,
        body: jsonEncode({}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCases(); // Refresh list after update
      }
    } catch (e) {
      debugPrint('Exception updating case: $e');
    }
  }
}
