import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Central API configuration.
/// On Android emulators, `localhost` resolves to the emulator device itself,
/// not the host machine. Use `10.0.2.2` as the host instead.
class ApiConfig {
  ApiConfig._(); // Prevent instantiation

  static String get host {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000'; // iOS / macOS / Windows
  }

  static String get baseUrl => '$host/api/v1';

  static String get socketUrl => host;

  static const String institutionId = 'edu-admin-123';

  // Demo fallback credentials
  static const String defaultAdminToken = 'jwt_mock_token_admin_sarah_chen';
  static const String defaultAdminRole = 'ADMIN';

  // Dynamic session credentials synchronized from AuthProvider
  static String? authToken;
  static String? userRole;
  static String? userEmail;
  static String? userName;
  static String? userPhone;
  static String? userId;
  static String? userDepartment;
  static String preferredContactChannel = 'Email';
  static String selectedLanguage = 'English';

  /// Returns standard headers for student requests
  static Map<String, String> get studentHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-institution-id': institutionId,
      'x-user-role': userRole ?? 'STUDENT',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
    if (userEmail != null) headers['x-user-email'] = userEmail!;
    if (userName != null) headers['x-user-name'] = userName!;
    return headers;
  }

  /// Returns standard headers for admin JSON API requests
  static Map<String, String> get adminHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-institution-id': institutionId,
      'x-user-role': userRole ?? defaultAdminRole,
      'Authorization': 'Bearer ${authToken ?? defaultAdminToken}',
    };
    if (userEmail != null) {
      headers['x-user-email'] = userEmail!;
    }
    return headers;
  }

  /// Returns standard headers for admin requests without Content-Type (GET, DELETE, Multipart)
  static Map<String, String> get adminAuthHeaders {
    final headers = <String, String>{
      'x-institution-id': institutionId,
      'x-user-role': userRole ?? defaultAdminRole,
      'Authorization': 'Bearer ${authToken ?? defaultAdminToken}',
    };
    if (userEmail != null) {
      headers['x-user-email'] = userEmail!;
    }
    return headers;
  }
}
