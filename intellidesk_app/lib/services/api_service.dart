import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticket.dart';
import '../config/api_config.dart';

export '../config/api_config.dart'; // Re-export so existing imports of api_service still work

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<List<Ticket>> fetchTickets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/tickets'),
      headers: ApiConfig.adminAuthHeaders,
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded.map((json) => Ticket.fromJson(json)).toList();
      } else if (decoded is Map<String, dynamic>) {
        final List<Ticket> allTickets = [];
        decoded.forEach((key, value) {
          if (value is List) {
            allTickets.addAll(value.map((json) => Ticket.fromJson(json)));
          }
        });
        return allTickets;
      }
      return [];
    } else {
      throw Exception('Failed to load tickets: ${response.statusCode}');
    }
  }

  Future<Ticket> fetchTicketById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/tickets/$id'),
      headers: ApiConfig.adminAuthHeaders,
    );
    if (response.statusCode == 200) {
      return Ticket.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load ticket: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> approveTicket(
    String id, {
    double? amount,
    String? payoutMethod,
    String? studentName,
    String? studentVpa,
    String? accountNumber,
    String? ifscCode,
  }) async {
    final bodyData = <String, dynamic>{};
    if (amount != null) bodyData['amount'] = amount;
    if (payoutMethod != null) bodyData['payout_method'] = payoutMethod;
    if (studentName != null && studentName.isNotEmpty) bodyData['student_name'] = studentName;
    if (studentVpa != null && studentVpa.isNotEmpty) bodyData['student_vpa'] = studentVpa;
    if (accountNumber != null && accountNumber.isNotEmpty) bodyData['account_number'] = accountNumber;
    if (ifscCode != null && ifscCode.isNotEmpty) bodyData['ifsc_code'] = ifscCode;

    final response = await http.post(
      Uri.parse('$baseUrl/admin/tickets/$id/approve'),
      headers: ApiConfig.adminHeaders,
      body: json.encode(bodyData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to approve ticket: ${response.statusCode}');
    }
  }

  Future<void> denyTicket(String id, {String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/tickets/$id/deny'),
      headers: ApiConfig.adminHeaders,
      body: json.encode({'notes': notes}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to deny ticket: ${response.statusCode}');
    }
  }

  String getExecutiveReportUrl({String timeframe = '30d'}) {
    return '$baseUrl/admin/reports/executive-pdf?timeframe=$timeframe';
  }

  Future<Map<String, dynamic>> sendVoiceIntake({
    required List<int> audioBytes,
    required String filename,
    String? studentName,
    String? studentContact,
  }) async {
    final uri = Uri.parse('$baseUrl/intake/voice');
    final request = http.MultipartRequest('POST', uri);
    request.headers['x-institution-id'] = ApiConfig.institutionId;

    if (studentName != null && studentName.isNotEmpty) {
      request.fields['studentName'] = studentName;
    }
    if (studentContact != null && studentContact.isNotEmpty) {
      request.fields['studentContact'] = studentContact;
    }

    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: filename,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 202) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Voice intake submission failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'x-institution-id': ApiConfig.institutionId,
      },
      body: json.encode({
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] != null) {
          throw Exception(decoded['error']);
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
      throw Exception('Invalid email or password (HTTP ${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> registerInstitution({
    required String instituteName,
    required String adminName,
    required String adminEmail,
    required String password,
    String defaultStudentPassword = 'Patient@123',
    required String institutionId,
    String? department,
    String? phone,
    double? initialFundPool,
    required List<Map<String, dynamic>> students,
    String? csvContent,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/admin/register-tenant'),
      headers: {
        'Content-Type': 'application/json',
        'x-institution-id': institutionId,
      },
      body: json.encode({
        'instituteName': instituteName,
        'adminName': adminName,
        'adminEmail': adminEmail,
        'password': password,
        'defaultStudentPassword': defaultStudentPassword,
        'institutionId': institutionId,
        'department': department ?? 'Clinical Triage & Emergency Copay Desk',
        'specialty': department ?? 'Clinical Triage & Emergency Copay Desk',
        'phone': phone ?? '+91 98111 22334',
        'fundPool': initialFundPool ?? 150000.0,
        'students': students,
        'csvContent': csvContent,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final decoded = json.decode(response.body);
      throw Exception(decoded['error'] ?? 'Institution registration failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'x-institution-id': ApiConfig.institutionId,
      },
      body: json.encode({
        'email': email,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && decoded['success'] == true) {
      return decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to update password');
    }
  }

  Future<Map<String, dynamic>> allocateHealthFund({
    required String name,
    required String category,
    required double amount,
    String currency = 'INR',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/telemetry/funds/allocate'),
      headers: ApiConfig.adminHeaders,
      body: json.encode({
        'name': name,
        'category': category,
        'amount': amount,
        'currency': currency,
      }),
    );

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to allocate health fund');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHealthFunds() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/telemetry/funds'),
      headers: ApiConfig.adminAuthHeaders,
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      return [];
    } else {
      throw Exception('Failed to fetch health funds');
    }
  }

  Future<Map<String, dynamic>> runCrisisStressTest({int scenarioCount = 10}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/simulation/run-stress-test'),
      headers: ApiConfig.adminHeaders,
      body: json.encode({'scenarioCount': scenarioCount}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Stress test simulation failed: ${response.statusCode}');
    }
  }
}
