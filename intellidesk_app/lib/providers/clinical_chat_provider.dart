import 'package:flutter/material.dart';
import '../models/claim_message.dart';
import '../models/emergency_helpline.dart';
import '../services/clinical_api_service.dart';
import '../services/socket_service.dart';

class ClinicalChatProvider extends ChangeNotifier {
  final ClinicalApiService _apiService;
  final SocketService _socketService;

  List<ClaimMessage> _messages = [];
  bool _isTyping = false;
  bool _isCrisisActive = false;
  List<EmergencyHelpline> _activeHelplines = [];
  String? _activeClaimId;

  ClinicalChatProvider({
    ClinicalApiService? apiService,
    SocketService? socketService,
  })  : _apiService = apiService ?? ClinicalApiService(),
        _socketService = socketService ?? SocketService() {
    _initSocket();
  }

  List<ClaimMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isCrisisActive => _isCrisisActive;
  List<EmergencyHelpline> get activeHelplines => _activeHelplines;

  void _initSocket() {
    _socketService.onChatMessage((data) {
      final msg = ClaimMessage(
        id: data['id']?.toString() ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
        claimId: data['claimId']?.toString() ?? _activeClaimId ?? '',
        sender: data['sender']?.toString() ?? 'COUNSELOR_AI',
        message: data['message']?.toString() ?? '',
        isCrisisResponse: data['isCrisisResponse'] == true,
      );

      _messages.add(msg);
      if (msg.isCrisisResponse) {
        _isCrisisActive = true;
        _activeHelplines = EmergencyHelpline.defaultHelplines;
      }
      notifyListeners();
    });
  }

  Future<void> initChat(String claimId) async {
    _activeClaimId = claimId;
    _socketService.joinClaim(claimId);
    
    try {
      _messages = await _apiService.fetchClaimMessages(claimId);
    } catch (_) {
      _messages = [];
    }

    if (_messages.isEmpty) {
      _messages.add(
        ClaimMessage(
          id: 'welcome-01',
          claimId: claimId,
          sender: 'COUNSELOR_AI',
          message: 'Hello. I am the MedAccess AI Clinical & Psychological First Aid Assistant. Take a steady breath. How can I help you today?',
        ),
      );
    }
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String patientPhone = 'patient-client'}) async {
    if (text.trim().isEmpty) return;

    final claimId = _activeClaimId ?? 'general';
    final userMsg = ClaimMessage(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      claimId: claimId,
      sender: 'PATIENT',
      message: text.trim(),
    );

    _messages.add(userMsg);
    _isTyping = true;
    notifyListeners();

    try {
      final res = await _apiService.sendCounselorMessage(
        claimId: claimId,
        message: text.trim(),
        patientPhone: patientPhone,
      );

      final reply = res['reply']?.toString() ?? 'Thank you. Our clinical team is processing your request.';
      final isCrisis = res['isCrisisResponse'] == true || res['isLifeSafetyAlert'] == true;

      final aiMsg = ClaimMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        claimId: claimId,
        sender: 'COUNSELOR_AI',
        message: reply,
        isCrisisResponse: isCrisis,
      );

      _messages.add(aiMsg);
      if (isCrisis) {
        _isCrisisActive = true;
        _activeHelplines = EmergencyHelpline.defaultHelplines;
      }
    } catch (e) {
      // Local Rogerian fallback
      _messages.add(
        ClaimMessage(
          id: 'fb-${DateTime.now().millisecondsSinceEpoch}',
          claimId: claimId,
          sender: 'COUNSELOR_AI',
          message: 'I hear what you are experiencing. Take a slow, calm breath with me—your request is actively in our clinical queue.',
        ),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}
