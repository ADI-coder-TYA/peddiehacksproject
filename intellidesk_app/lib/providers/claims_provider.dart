import 'package:flutter/material.dart';
import '../models/claim.dart';
import '../services/clinical_api_service.dart';
import '../services/socket_service.dart';

class ClaimsProvider extends ChangeNotifier {
  final ClinicalApiService _apiService;
  final SocketService _socketService;

  List<Claim> _claims = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeEsiFilter = 'ALL';

  ClaimsProvider({
    ClinicalApiService? apiService,
    SocketService? socketService,
  })  : _apiService = apiService ?? ClinicalApiService(),
        _socketService = socketService ?? SocketService() {
    _initSocketListeners();
  }

  List<Claim> get claims => _claims;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeEsiFilter => _activeEsiFilter;

  List<Claim> get filteredClaims {
    if (_activeEsiFilter == 'ESI_1') {
      return _claims.where((c) => c.esiLevel == 'ESI_1_CRITICAL' || c.isLifeSafetyAlert).toList();
    } else if (_activeEsiFilter == 'ESI_2') {
      return _claims.where((c) => c.esiLevel == 'ESI_2_EMERGENT').toList();
    } else if (_activeEsiFilter == 'FLAGGED') {
      return _claims.where((c) => c.status == 'Flagged' || (c.fraudRiskScore != null && c.fraudRiskScore! > 0.6)).toList();
    }
    return _claims;
  }

  void setEsiFilter(String filter) {
    _activeEsiFilter = filter;
    notifyListeners();
  }

  void _initSocketListeners() {
    _socketService.onClaimUpdated((claimData) {
      final updatedClaim = Claim.fromJson(claimData);
      final index = _claims.indexWhere((c) => c.id == updatedClaim.id);
      if (index != -1) {
        _claims[index] = updatedClaim;
      } else {
        _claims.insert(0, updatedClaim);
      }
      notifyListeners();
    });

    _socketService.onClaimDisbursed((data) {
      final claimId = data['claimId']?.toString();
      if (claimId != null) {
        final index = _claims.indexWhere((c) => c.id == claimId);
        if (index != -1) {
          _claims[index] = Claim(
            id: _claims[index].id,
            institutionId: _claims[index].institutionId,
            patientId: _claims[index].patientId,
            patientPhone: _claims[index].patientPhone,
            description: _claims[index].description,
            clinicalCategory: _claims[index].clinicalCategory,
            esiLevel: _claims[index].esiLevel,
            crisisSeverityIndex: _claims[index].crisisSeverityIndex,
            isLifeSafetyAlert: _claims[index].isLifeSafetyAlert,
            receiptUrl: _claims[index].receiptUrl,
            extractedBillAmount: _claims[index].extractedBillAmount,
            currency: _claims[index].currency,
            recommendedCopayAmount: _claims[index].recommendedCopayAmount,
            approvedAmount: (data['approvedAmount'] as num?)?.toDouble() ?? _claims[index].approvedAmount,
            fraudRiskScore: _claims[index].fraudRiskScore,
            status: 'Disbursed',
            payoutReference: data['payoutReference']?.toString(),
            payoutMethod: data['payoutMethod']?.toString(),
            createdAt: _claims[index].createdAt,
          );
          notifyListeners();
        }
      }
    });
  }

  Future<void> fetchClaims() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _claims = await _apiService.fetchClaims();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> disburseCopay(String claimId, double amount, {String payoutMethod = 'RAZORPAY_UPI', String? notes}) async {
    try {
      await _apiService.disburseCopay(
        claimId: claimId,
        approvedAmount: amount,
        payoutMethod: payoutMethod,
        adminNotes: notes,
      );
      await fetchClaims();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
