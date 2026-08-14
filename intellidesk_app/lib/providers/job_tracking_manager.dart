import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

enum JobState {
  idle,
  queued,
  transcription,
  policyMatching,
  mlScoring,
  completed,
  failed,
}

class JobTrackingManager extends ChangeNotifier {
  final io.Socket socket;
  final http.Client httpClient;
  final String apiBaseUrl;

  String? _currentJobId;
  JobState _currentState = JobState.idle;
  String _statusMessage = 'No active intake jobs.';
  Map<String, dynamic>? _jobResult;
  String? _errorMessage;

  Timer? _pollingTimer;
  int _pollingDelayMs = 2000;
  bool _isPolling = false;

  String? get currentJobId => _currentJobId;
  JobState get currentState => _currentState;
  String get statusMessage => _statusMessage;
  Map<String, dynamic>? get jobResult => _jobResult;
  String? get errorMessage => _errorMessage;

  JobTrackingManager({
    required this.socket,
    required this.httpClient,
    required this.apiBaseUrl,
  }) {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    socket.on('job:progress', (data) {
      if (data['jobId'] == _currentJobId) {
        _handleProgressUpdate(data['step']);
      }
    });

    socket.on('job:completed', (data) {
      if (data['jobId'] == _currentJobId) {
        _stopPolling();
        _currentState = JobState.completed;
        _jobResult = data['result'] is Map<String, dynamic>
            ? data['result'] as Map<String, dynamic>
            : null;
        _statusMessage = 'Request processed successfully.';
        notifyListeners();
      }
    });

    // Fallback: ticket:updated is emitted even if job:completed is missed
    socket.on('ticket:updated', (data) {
      if (_currentJobId == null || _currentState == JobState.completed || _currentState == JobState.failed) return;
      final ticketId = data['ticket_id'] ?? data['ticketId'];
      // If we don't know the ticketId yet but have a jobId, accept any update as completion
      final status = (data['status'] as String? ?? '').toLowerCase();
      if (status == 'auto-approved' || status == 'escalated' || status == 'pending') {
        _stopPolling();
        _currentState = JobState.completed;
        _jobResult = {
          'status': data['status'],
          'ticketId': ticketId,
          'crisisSeverityIndex': data['crisis_severity_index'],
          'voucherCode': data['voucher_code'],
        };
        _statusMessage = 'Request processed successfully.';
        notifyListeners();
      }
    });

    socket.on('job:failed', (data) {
      if (data['jobId'] == _currentJobId) {
        _stopPolling();
        _currentState = JobState.failed;
        _errorMessage = data['error'] ?? 'An unknown error occurred.';
        _statusMessage = 'Processing failed.';
        notifyListeners();
      }
    });

    // If socket disconnects, kick off HTTP fallback polling
    socket.onDisconnect((_) {
      if (_currentJobId != null && 
          _currentState != JobState.completed && 
          _currentState != JobState.failed) {
        _startHttpFallbackPolling();
      }
    });

    socket.onConnect((_) {
      _stopPolling();
    });
  }

  void startTracking(String jobId) {
    _currentJobId = jobId;
    _currentState = JobState.queued;
    _statusMessage = 'Request queued in background...';
    _jobResult = null;
    _errorMessage = null;
    notifyListeners();

    // Always start HTTP polling as a safety net alongside socket
    _startHttpFallbackPolling();
  }

  void stopTracking() {
    _currentJobId = null;
    _currentState = JobState.idle;
    _statusMessage = 'No active intake jobs.';
    _stopPolling();
    notifyListeners();
  }

  void _handleProgressUpdate(String step) {
    switch (step) {
      case 'TRANSCRIPTION_COMPLETE':
        _currentState = JobState.policyMatching;
        _statusMessage = 'Analyzing text & matching university policies...';
        break;
      case 'POLICY_MATCHED':
        _currentState = JobState.mlScoring;
        _statusMessage = 'Running predictive ML models for decisioning...';
        break;
      case 'ML_SCORED':
        _currentState = JobState.completed; // Handled directly by job:completed usually
        break;
      default:
        _statusMessage = 'Processing ($step)...';
    }
    notifyListeners();
  }

  void _startHttpFallbackPolling() {
    if (_isPolling || _currentJobId == null) return;
    _isPolling = true;
    _pollingDelayMs = 2000;
    _poll();
  }

  void _stopPolling() {
    _isPolling = false;
    _pollingTimer?.cancel();
  }

  Future<void> _poll() async {
    if (!_isPolling || _currentJobId == null) return;

    try {
      final response = await httpClient.get(
        Uri.parse('$apiBaseUrl/api/v1/intake/status/$_currentJobId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String? ?? '';

        if (status == 'completed') {
          _stopPolling();
          _currentState = JobState.completed;
          final result = data['result'];
          _jobResult = result is Map<String, dynamic> ? result : null;
          _statusMessage = 'Request processed successfully.';
          notifyListeners();
          return;
        } else if (status == 'failed') {
          _stopPolling();
          _currentState = JobState.failed;
          _errorMessage = data['failedReason'] ?? data['error'] ?? 'An unknown error occurred.';
          _statusMessage = 'Processing failed.';
          notifyListeners();
          return;
        } else if (status == 'active') {
          final progress = data['progress'];
          if (progress is String) {
            _handleProgressUpdate(progress);
          } else if (_currentState == JobState.queued) {
            _currentState = JobState.transcription;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }

    // Exponential backoff capped at 16 seconds
    if (_isPolling) {
      _pollingTimer = Timer(Duration(milliseconds: _pollingDelayMs), _poll);
      _pollingDelayMs = (_pollingDelayMs * 2).clamp(2000, 16000);
    }
  }
}
