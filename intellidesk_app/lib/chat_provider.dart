// ============================================================
//  IntelliDesk EduAccess — Chat State & Network Service
//  Handles: multi-turn crisis counselor dialogues, PFA streaming,
//  emergency hotline card injection, ticket confirmation gates,
//  and async triage socket updates.
// ============================================================

import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'config/api_config.dart';

// ─── Emergency Resource Model ─────────────────────────────────

class EmergencyResource {
  final String name;
  final String number;
  final String category;
  final String actionUrl;
  final String description;
  final String icon;

  const EmergencyResource({
    required this.name,
    required this.number,
    required this.category,
    required this.actionUrl,
    required this.description,
    required this.icon,
  });

  factory EmergencyResource.fromJson(Map<String, dynamic> json) {
    final num = json['number']?.toString() ?? '';
    final action = json['actionUrl']?.toString() ?? (num.isNotEmpty ? 'tel:$num' : '');
    return EmergencyResource(
      name: json['name']?.toString() ?? 'Emergency Helpline',
      number: num,
      category: json['category']?.toString() ?? 'Crisis Support',
      actionUrl: action,
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'phone',
    );
  }
}

// ─── Message Model ───────────────────────────────────────────

enum MessageSender { student, assistant }

enum MessageType { text, image, file }

class AttachmentData {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const AttachmentData({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

class ChatMessage {
  final String id;
  final MessageSender sender;
  final MessageType type;
  final String text;
  final AttachmentData? attachment;
  final DateTime timestamp;

  /// Non-null when the backend auto-approved a financial request.
  final String? voucherCode;

  /// True while awaiting a reply from the backend.
  final bool isLoading;

  /// Associated ticket ID
  final String? ticketId;

  /// Indicates if this response triggered life-safety critical protocol
  final bool isCrisisResponse;

  /// Indicates if counselor is asking user whether to log an official ticket
  final bool requiresConfirmation;

  /// Indicates if ticket is officially logged in DB
  final bool isTicketLogged;

  /// Emergency crisis resources / hotlines
  final List<EmergencyResource>? resources;

  const ChatMessage({
    required this.id,
    required this.sender,
    this.type = MessageType.text,
    required this.text,
    this.attachment,
    required this.timestamp,
    this.voucherCode,
    this.isLoading = false,
    this.ticketId,
    this.isCrisisResponse = false,
    this.requiresConfirmation = false,
    this.isTicketLogged = false,
    this.resources,
  });

  ChatMessage copyWith({
    String? text,
    String? voucherCode,
    bool? isLoading,
    String? ticketId,
    bool? isCrisisResponse,
    bool? requiresConfirmation,
    bool? isTicketLogged,
    List<EmergencyResource>? resources,
  }) {
    return ChatMessage(
      id: id,
      sender: sender,
      type: type,
      text: text ?? this.text,
      attachment: attachment,
      timestamp: timestamp,
      voucherCode: voucherCode ?? this.voucherCode,
      isLoading: isLoading ?? this.isLoading,
      ticketId: ticketId ?? this.ticketId,
      isCrisisResponse: isCrisisResponse ?? this.isCrisisResponse,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      isTicketLogged: isTicketLogged ?? this.isTicketLogged,
      resources: resources ?? this.resources,
    );
  }
}

// ─── Network Response Model ───────────────────────────────────

class IntakeResponse {
  final String status; // 'Pending' | 'Auto-Approved' | 'Error' | 'queued' | 'Active'
  final String message;
  final String? voucherCode;
  final String? urgencyLevel;
  final String? category;
  final String? ticketId;
  final String? jobId;
  final String? counselorReply;
  final bool isCrisisResponse;
  final bool requiresConfirmation;
  final bool isTicketLogged;
  final List<EmergencyResource>? resources;

  const IntakeResponse({
    required this.status,
    required this.message,
    this.voucherCode,
    this.urgencyLevel,
    this.category,
    this.ticketId,
    this.jobId,
    this.counselorReply,
    this.isCrisisResponse = false,
    this.requiresConfirmation = false,
    this.isTicketLogged = false,
    this.resources,
  });

  factory IntakeResponse.fromJson(Map<String, dynamic> json) {
    List<EmergencyResource>? parsedResources;
    if (json['resources'] is List) {
      parsedResources = (json['resources'] as List)
          .map((r) => EmergencyResource.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }

    final reply = json['reply']?.toString() ?? json['counselorReply']?.toString();

    return IntakeResponse(
      status: json['status'] as String? ?? (reply != null ? 'Active' : 'Pending'),
      message: json['message'] as String? ?? (reply ?? 'Request received.'),
      voucherCode: json['voucherCode'] as String?,
      urgencyLevel: json['urgencyLevel'] as String?,
      category: json['category'] as String?,
      ticketId: (json['ticketId'] ?? json['ticket_id'] ?? json['id']) as String?,
      jobId: json['jobId']?.toString(),
      counselorReply: reply,
      isCrisisResponse: json['isCrisisResponse'] == true || json['is_crisis_response'] == true,
      requiresConfirmation: json['requiresConfirmation'] == true,
      isTicketLogged: json['isTicketLogged'] == true || (json['ticketId'] != null && json['ticketId'] != ''),
      resources: parsedResources,
    );
  }

  factory IntakeResponse.error(String errorMessage) {
    return IntakeResponse(
      status: 'Error',
      message: errorMessage,
    );
  }
}

// ─── Chat Provider (ChangeNotifier) ──────────────────────────

class ChatProvider extends ChangeNotifier {
  String get _intakeEndpoint => '${ApiConfig.baseUrl}/intake/web';
  String get _chatEndpoint => '${ApiConfig.baseUrl}/chat/message';

  // ── State ──────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _statusHint; // e.g., "Assessing emergency guidelines..."
  String? get statusHint => _statusHint;

  String? _currentTicketId;
  String? get currentTicketId => _currentTicketId;

  io.Socket? _socket;

  String _uniqueId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_messages.length}';

  // ── Initialization ─────────────────────────────────────────
  ChatProvider() {
    _addSystemWelcome();
    _initSocket();
  }

  void _initSocket() {
    try {
      _socket = io.io(ApiConfig.socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });

      _socket?.on('chat:new_message', (data) {
        if (data is Map) {
          final ticketId = data['ticketId']?.toString() ?? data['ticket_id']?.toString();
          final sender = data['sender']?.toString();
          final msgText = data['message']?.toString() ?? '';
          final isCrisis = data['isCrisisResponse'] == true || data['is_crisis_response'] == true;

          // If message is from counselor/admin and not already present, display it
          if (sender == 'COUNSELOR_AI' || sender == 'HUMAN_ADMIN') {
            final alreadyPresent = _messages.any((m) => m.text == msgText && m.sender == MessageSender.assistant);
            if (!alreadyPresent) {
              List<EmergencyResource>? resList;
              if (data['resources'] is List) {
                resList = (data['resources'] as List)
                    .map((r) => EmergencyResource.fromJson(Map<String, dynamic>.from(r)))
                    .toList();
              }
              _messages.add(ChatMessage(
                id: _uniqueId(),
                sender: MessageSender.assistant,
                text: msgText,
                timestamp: DateTime.now(),
                ticketId: ticketId,
                isCrisisResponse: isCrisis,
                isTicketLogged: true,
                resources: resList,
              ));
              notifyListeners();
            }
          }
        }
      });

      _socket?.on('job:progress', (data) {
        if (data is Map) {
          final step = data['step']?.toString();
          if (step == 'TRANSCRIPTION_COMPLETE') {
            _statusHint = 'Matching institutional policies...';
          } else if (step == 'POLICY_MATCHED') {
            _statusHint = 'Running AI distress & risk models...';
          } else if (step == 'ML_SCORED') {
            _statusHint = 'Finalizing grant adjudication...';
          }
          notifyListeners();
        }
      });

      _socket?.on('ticket:updated', (data) {
        if (data is Map) {
          _handleTicketUpdate(Map<String, dynamic>.from(data));
        }
      });

      _socket?.on('job:completed', (data) {
        if (data is Map) {
          _handleJobCompleted(Map<String, dynamic>.from(data));
        }
      });
    } catch (e) {
      debugPrint('[ChatProvider] Socket init error: $e');
    }
  }

  void _handleTicketUpdate(Map<String, dynamic> data) {
    final ticketId = data['id']?.toString() ?? data['ticketId']?.toString();
    if (ticketId == null) return;

    // Check if an existing status card already exists for this ticket
    final existingStatusIndex = _messages.indexWhere(
      (m) =>
          m.sender == MessageSender.assistant &&
          m.ticketId == ticketId &&
          (m.text.contains('Case Escalated') ||
              m.text.contains('Emergency Grant Approved') ||
              m.text.contains('Assessment Complete')),
    );

    String? rawCategory = data['parsed_category']?.toString() ?? data['category']?.toString();
    String category = rawCategory ?? 'Medical';
    if (rawCategory == null && existingStatusIndex != -1) {
      final oldText = _messages[existingStatusIndex].text;
      final match = RegExp(r'Category:\s*([^\n]+)').firstMatch(oldText);
      if (match != null && match.group(1) != null && match.group(1) != 'General Support') {
        category = match.group(1)!;
      }
    }

    final status = data['status']?.toString() ?? 'Pending';
    final urgency = data['urgency_level']?.toString() ?? data['urgencyLevel']?.toString() ?? 'Critical';
    final grantAmount = data['recommended_grant_amount'] ?? data['recommendedGrantAmount'] ?? data['amount'];
    final voucherCode = data['voucher_code']?.toString() ?? data['voucherCode']?.toString();
    final policyReason = data['policy_match_reason']?.toString();

    String responseText;
    if (status == 'Approved' || status == 'Auto-Approved') {
      responseText = '🎉 Emergency Grant Approved!\n\n'
          'Category: $category ($urgency Urgency)\n'
          '${grantAmount != null && grantAmount != 0 ? "Approved Grant Amount: \$$grantAmount\n\n" : ""}'
          '${voucherCode != null ? "Voucher Code: $voucherCode\n\nPresent this code at Student Services or designated campus facilities." : "Approval confirmation sent to your student profile."}';
    } else if (status == 'Denied') {
      responseText = 'Update: Your request has been reviewed by the Student Welfare Committee. '
          'Please check your student email for further options or contact the welfare desk.';
    } else if (status == 'Escalated' || urgency == 'Critical' || urgency == 'High') {
      final shortId = ticketId.length > 8 ? ticketId.substring(0, 8) : ticketId;
      responseText = '🚨 Case Escalated to Welfare Team ($urgency Priority)\n\n'
          'Ticket: #$shortId\n'
          'Category: $category\n'
          '${grantAmount != null && grantAmount != 0 ? "AI Recommended Emergency Grant: \$$grantAmount\n\n" : ""}'
          '${policyReason != null && policyReason.isNotEmpty ? "Context: $policyReason\n\n" : ""}'
          'A senior university welfare counselor has been notified immediately. Emergency crisis support is on standby.';
    } else {
      final shortId = ticketId.length > 8 ? ticketId.substring(0, 8) : ticketId;
      responseText = '📋 Assessment Complete (Ticket #$shortId)\n\n'
          'Category: $category\n'
          'Status: $status ($urgency Priority)\n'
          '${grantAmount != null && grantAmount != 0 ? "Recommended Grant: \$$grantAmount\n\n" : ""}'
          'Your case has been logged and assigned to the welfare office.';
    }

    final loadingIndex = _messages.lastIndexWhere(
      (m) =>
          m.sender == MessageSender.assistant &&
          (m.isLoading ||
              (m.ticketId == ticketId && m.text.contains('analyzed by the AI Crisis Advisor'))),
    );

    if (existingStatusIndex != -1) {
      // Update existing status card in-place (never append duplicate)
      _messages[existingStatusIndex] = ChatMessage(
        id: _messages[existingStatusIndex].id,
        sender: MessageSender.assistant,
        text: responseText,
        voucherCode: voucherCode ?? _messages[existingStatusIndex].voucherCode,
        timestamp: DateTime.now(),
        ticketId: ticketId,
        isTicketLogged: true,
        isLoading: false,
      );
    } else if (loadingIndex != -1 && _messages[loadingIndex].isLoading) {
      // Replace loading bubble
      _messages[loadingIndex] = ChatMessage(
        id: _messages[loadingIndex].id,
        sender: MessageSender.assistant,
        text: responseText,
        voucherCode: voucherCode,
        timestamp: DateTime.now(),
        ticketId: ticketId,
        isTicketLogged: true,
        isLoading: false,
      );
    } else if (status == 'Approved' || status == 'Auto-Approved' || status == 'Escalated' || urgency == 'Critical' || urgency == 'High') {
      _messages.add(ChatMessage(
        id: _uniqueId(),
        sender: MessageSender.assistant,
        text: responseText,
        voucherCode: voucherCode,
        timestamp: DateTime.now(),
        isTicketLogged: true,
        ticketId: ticketId,
      ));
    }

    _statusHint = null;
    _isSending = false;
    notifyListeners();
  }

  void _handleJobCompleted(Map<String, dynamic> data) {
    final ticketId = data['ticketId']?.toString();
    final result = data['result'];
    if (result is Map) {
      final resultMap = Map<String, dynamic>.from(result);
      if (ticketId != null && !resultMap.containsKey('id')) {
        resultMap['id'] = ticketId;
      }
      _handleTicketUpdate(resultMap);
    }
  }

  void _addSystemWelcome() {
    _messages.add(ChatMessage(
      id: _uniqueId(),
      sender: MessageSender.assistant,
      text:
          'Hi! I am your University Crisis Counselor & Welfare Advisor. '
          'Please share what you are experiencing. '
          'I can provide immediate guidance, and if needed, help you submit an emergency grant request.',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────

  /// Send a text-only or multimodal message to the conversational counselor.
  Future<void> sendMessage({
    required String text,
    AttachmentData? attachment,
    bool confirmTicket = false,
  }) async {
    if (text.trim().isEmpty && attachment == null) return;
    if (_isSending) return;

    // 1. Append student bubble
    final studentMsg = ChatMessage(
      id: _uniqueId(),
      sender: MessageSender.student,
      type: attachment != null ? MessageType.image : MessageType.text,
      text: text.trim(),
      attachment: attachment,
      timestamp: DateTime.now(),
    );
    _messages.add(studentMsg);

    // 2. Append loading indicator bubble
    final loaderId = _uniqueId();
    _messages.add(ChatMessage(
      id: loaderId,
      sender: MessageSender.assistant,
      text: '',
      timestamp: DateTime.now(),
      isLoading: true,
    ));

    _isSending = true;
    _statusHint = confirmTicket ? 'Submitting Emergency Ticket...' : 'Counselor is typing...';
    notifyListeners();

    // 3. Perform network call
    late IntakeResponse response;
    try {
      if (attachment != null) {
        response = await _postMultipart(
          text: text.trim(),
          attachment: attachment,
        );
      } else {
        response = await _postCounselorMessage(
          text: text.trim(),
          confirmTicket: confirmTicket,
        );
      }
    } catch (e) {
      response = IntakeResponse.error('Connection notice: ${e.toString()}');
    }

    // 4. Update current active ticket ID if ticket was logged
    if (response.ticketId != null && response.ticketId!.isNotEmpty) {
      _currentTicketId = response.ticketId;
      _socket?.emit('join_ticket', response.ticketId);
    }

    // 5. Replace loading bubble with counselor response
    final loaderIndex = _messages.indexWhere((m) => m.id == loaderId);
    if (loaderIndex != -1) {
      _messages[loaderIndex] = _buildResponseBubble(response);
    }

    _isSending = false;
    _statusHint = null;
    notifyListeners();
  }

  /// Retry the last failed student message.
  Future<void> retryLast() async {
    if (_isSending) return;
    final lastStudent = _messages.lastWhere(
      (m) => m.sender == MessageSender.student,
      orElse: () => throw StateError('No student messages to retry'),
    );
    await sendMessage(
      text: lastStudent.text,
      attachment: lastStudent.attachment,
    );
  }

  /// Clear all messages and reset to welcome state.
  void clearChat() {
    _messages.clear();
    _currentTicketId = null;
    _addSystemWelcome();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  //  MEDIA ENCODING
  // ─────────────────────────────────────────────────────────────

  /// Convert raw bytes to a base64-encoded data URI string.
  static String encodeToBase64DataUri(AttachmentData data) {
    final encoded = base64Encode(data.bytes);
    return 'data:${data.mimeType};base64,$encoded';
  }

  /// Build [AttachmentData] from a file path (non-web only).
  static Future<AttachmentData> attachmentFromPath(
    String path, {
    required String mimeType,
  }) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return AttachmentData(
      fileName: path.split(Platform.pathSeparator).last,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  /// Build [AttachmentData] from raw bytes (web / cross-platform).
  static AttachmentData attachmentFromBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) {
    return AttachmentData(fileName: fileName, mimeType: mimeType, bytes: bytes);
  }

  // ─────────────────────────────────────────────────────────────
  //  PRIVATE — HTTP LAYER
  // ─────────────────────────────────────────────────────────────

  /// POST to conversational counselor endpoint
  Future<IntakeResponse> _postCounselorMessage({
    required String text,
    bool confirmTicket = false,
  }) async {
    final uri = Uri.parse(_chatEndpoint);
    final studentName = ApiConfig.userName ?? (ApiConfig.userEmail != null ? ApiConfig.userEmail!.split('@')[0] : 'Student');
    final studentContact = ApiConfig.userPhone?.isNotEmpty == true ? ApiConfig.userPhone! : (ApiConfig.userEmail ?? '+15550000000');

    // Find the last student message that carried the hardship context
    String? contextMessage;
    if (confirmTicket) {
      final priorStudentMsgs = _messages
          .where((m) => m.sender == MessageSender.student && m.text != text && m.text.isNotEmpty)
          .map((m) => m.text)
          .toList();
      if (priorStudentMsgs.isNotEmpty) {
        contextMessage = priorStudentMsgs.last;
      }
    }

    final history = _messages
        .where((m) => m.text.isNotEmpty && !m.isLoading)
        .map((m) => {
              'sender': m.sender == MessageSender.student ? 'STUDENT' : 'COUNSELOR_AI',
              'message': m.text,
            })
        .toList();

    final body = jsonEncode({
      'ticketId': _currentTicketId,
      'studentName': studentName,
      'studentPhone': studentContact,
      'message': text,
      'contextMessage': contextMessage,
      'history': history,
      'confirmTicket': confirmTicket,
    });

    final resp = await http
        .post(uri, headers: {'Content-Type': 'application/json', 'x-institution-id': ApiConfig.institutionId}, body: body)
        .timeout(const Duration(seconds: 45));

    return _parseHttpResponse(resp);
  }

  /// Multipart POST carrying text + file bytes (image / PDF) to web intake.
  Future<IntakeResponse> _postMultipart({
    required String text,
    required AttachmentData attachment,
  }) async {
    final uri = Uri.parse(_intakeEndpoint);
    final request = http.MultipartRequest('POST', uri);
    final studentName = ApiConfig.userName ?? (ApiConfig.userEmail != null ? ApiConfig.userEmail!.split('@')[0] : 'Student');
    final studentContact = ApiConfig.userPhone?.isNotEmpty == true ? ApiConfig.userPhone! : (ApiConfig.userEmail ?? '+15550000000');

    // Metadata fields
    request.headers['x-institution-id'] = ApiConfig.institutionId;
    request.fields['studentName'] = studentName;
    request.fields['studentContact'] = studentContact;
    request.fields['message'] = text;

    final dataUri = encodeToBase64DataUri(attachment);
    request.fields['media_url'] = dataUri;
    request.fields['attachment_url'] = dataUri;
    request.fields['mediaUrl'] = dataUri;
    request.fields['attachmentUrl'] = dataUri;

    // Attach the file as multipart bytes
    request.files.add(
      http.MultipartFile.fromBytes(
        'attachment',
        attachment.bytes,
        filename: attachment.fileName,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);
    return _parseHttpResponse(resp);
  }

  // ─────────────────────────────────────────────────────────────
  //  RESPONSE PARSING
  // ─────────────────────────────────────────────────────────────

  IntakeResponse _parseHttpResponse(http.Response resp) {
    if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 202) {
      try {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return IntakeResponse.fromJson(json);
      } catch (_) {
        return const IntakeResponse(
          status: 'Pending',
          message: 'I hear you. Your request is being prioritized and welfare counselors are standing by.',
        );
      }
    }
    return IntakeResponse.error(
      'Server response (${resp.statusCode}). Please check your connection.',
    );
  }

  ChatMessage _buildResponseBubble(IntakeResponse response) {
    String text;
    String? voucherCode;

    if (response.counselorReply != null && response.counselorReply!.isNotEmpty) {
      text = response.counselorReply!;
    } else {
      switch (response.status) {
        case 'Auto-Approved':
          voucherCode = response.voucherCode;
          text =
              'Great news! Your ${response.category ?? "financial"} request '
              'has been auto-approved based on university welfare guidelines.\n\n'
              '${voucherCode != null ? "Your pharmacy / welfare voucher code is:\n$voucherCode\n\nPresent this at the Student Services counter." : "Approval details have been sent to your registered contact."}';
          break;

        case 'Error':
          text =
              'We encountered an issue processing your request:\n'
              '${response.message}\n\n'
              'Please try again or contact the Student Welfare Office directly.';
          break;

        case 'queued':
        case 'Pending':
        default:
          final shortId = (response.ticketId != null && response.ticketId!.length > 8)
              ? response.ticketId!.substring(0, 8)
              : (response.ticketId ?? "—");
          text =
              'I hear how challenging this is right now. Your request (Ticket #$shortId) has been received and our welfare team is coordinating immediate relief.\n\n'
              'Please feel free to tell me more about what is going on.';
      }
    }

    return ChatMessage(
      id: _uniqueId(),
      sender: MessageSender.assistant,
      text: text,
      timestamp: DateTime.now(),
      voucherCode: voucherCode,
      ticketId: response.ticketId,
      isCrisisResponse: response.isCrisisResponse,
      requiresConfirmation: response.requiresConfirmation,
      isTicketLogged: response.isTicketLogged,
      resources: response.resources,
    );
  }
}
