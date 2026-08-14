import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/claim.dart';
import '../models/claim_message.dart';

class ClinicalApiService {
  final http.Client _client;
  final String _baseUrl;

  ClinicalApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.host;

  /// Submit a new clinical claim or copay assistance request
  Future<Map<String, dynamic>> submitClaim({
    required String patientPhone,
    required String description,
    required String clinicalCategory,
    String? mediaUrl,
    String institutionId = 'default',
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/intake/web');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'studentPhone': patientPhone,
        'patientPhone': patientPhone,
        'description': description,
        'message': description,
        'clinicalCategory': clinicalCategory,
        'category': clinicalCategory,
        'media_url': mediaUrl,
        'institutionId': institutionId,
        'source': 'flutter-portal',
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to submit claim (${response.statusCode}): ${response.body}');
  }

  /// Fetch all claims with optional ESI and status filtering
  Future<List<Claim>> fetchClaims({
    String? esiLevel,
    String? status,
    String? search,
    String institutionId = 'default',
  }) async {
    final queryParams = <String, String>{'institutionId': institutionId};
    if (esiLevel != null) queryParams['esiLevel'] = esiLevel;
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/api/v1/claims').replace(queryParameters: queryParams);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Claim.fromJson(json as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch claims: ${response.statusCode}');
  }

  /// Fetch a single claim by ID
  Future<Claim> fetchClaimById(String id) async {
    final url = Uri.parse('$_baseUrl/api/v1/claims/$id');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return Claim.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch claim #$id');
  }

  /// Disburse emergency copay relief
  Future<Map<String, dynamic>> disburseCopay({
    required String claimId,
    required double approvedAmount,
    String payoutMethod = 'RAZORPAY_UPI',
    String? adminNotes,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/claims/$claimId/disburse');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'approvedAmount': approvedAmount,
        'payoutMethod': payoutMethod,
        'adminNotes': adminNotes,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Disbursement failed (${response.statusCode}): ${response.body}');
  }

  /// Send message to PFA clinical counselor
  Future<Map<String, dynamic>> sendCounselorMessage({
    required String claimId,
    required String message,
    String patientPhone = 'patient-client',
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/chat/claims/$claimId/messages');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'patientPhone': patientPhone,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send counselor message');
  }

  /// Fetch message history for a claim
  Future<List<ClaimMessage>> fetchClaimMessages(String claimId) async {
    final url = Uri.parse('$_baseUrl/api/v1/chat/claims/$claimId/messages');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ClaimMessage.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
