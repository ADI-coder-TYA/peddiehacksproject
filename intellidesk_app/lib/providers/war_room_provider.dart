import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/claim.dart';
import '../models/health_fund.dart';
import '../services/socket_service.dart';

class WarRoomProvider extends ChangeNotifier {
  final SocketService _socketService;
  final http.Client _client;

  List<Claim> _claims = [];
  List<HealthFund> _funds = [];
  double _totalDisbursed = 104600.0;
  double _totalAllocated = 150000.0;
  int _activeEsiCritical = 6;
  double _ocrAccuracy = 98.4;
  bool _isLoading = false;
  String? _errorMessage;

  WarRoomProvider({
    SocketService? socketService,
    http.Client? client,
  })  : _socketService = socketService ?? SocketService(),
        _client = client ?? http.Client() {
    _initSocket();
  }

  List<Claim> get claims => _claims;
  List<HealthFund> get funds => _funds;
  double get totalDisbursed => _totalDisbursed;
  double get remainingLiquidity => (_totalAllocated - _totalDisbursed).clamp(0.0, _totalAllocated);
  int get activeEsiCritical => _activeEsiCritical;
  double get ocrAccuracy => _ocrAccuracy;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initSocket() {
    _socketService.onEmergencyAlert((data) {
      _activeEsiCritical++;
      notifyListeners();
    });

    _socketService.onClaimDisbursed((data) {
      final amt = (data['approvedAmount'] as num?)?.toDouble() ?? 0.0;
      _totalDisbursed += amt;
      notifyListeners();
    });
  }

  Future<void> fetchWarRoomData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _client.get(Uri.parse('${ApiConfig.host}/api/v1/claims'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _claims = data.map((json) => Claim.fromJson(json as Map<String, dynamic>)).toList();
        _activeEsiCritical = _claims.where((c) => c.esiLevel == 'ESI_1_CRITICAL' || c.isLifeSafetyAlert).length;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
