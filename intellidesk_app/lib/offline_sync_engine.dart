import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';

// ============================================================================
// Data Models
// ============================================================================
class QueuedRequest {
  final String id;
  final String rawMessage;
  final String? filePath;
  final String? studentName;
  final String? studentContact;
  final DateTime timestamp;

  QueuedRequest({
    required this.id,
    required this.rawMessage,
    this.filePath,
    this.studentName,
    this.studentContact,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'rawMessage': rawMessage,
    'filePath': filePath,
    'studentName': studentName,
    'studentContact': studentContact,
    'timestamp': timestamp.toIso8601String(),
  };

  factory QueuedRequest.fromJson(Map<String, dynamic> json) => QueuedRequest(
    id: json['id'] as String,
    rawMessage: json['rawMessage'] as String? ?? '',
    filePath: json['filePath'] as String?,
    studentName: json['studentName'] as String?,
    studentContact: json['studentContact'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
  );
}

// ============================================================================
// 1. Offline Storage & Voucher Cache Engine (OfflineVoucherStore)
// ============================================================================
class OfflineVoucherStore {
  static const String _vouchersKey = 'cached_digital_vouchers';
  
  static Future<void> cacheVoucher(String ticketId, String hashedClaimCode, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cached = prefs.getStringList(_vouchersKey) ?? [];
    
    if (cached.any((v) => jsonDecode(v)['ticketId'] == ticketId)) return;

    final voucherData = jsonEncode({
      'ticketId': ticketId,
      'claimCode': hashedClaimCode,
      'amount': amount,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    
    cached.add(voucherData);
    await prefs.setStringList(_vouchersKey, cached);
    debugPrint('Voucher Cached for Offline Use: $ticketId');
  }

  static Future<List<Map<String, dynamic>>> getCachedVouchers() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cached = prefs.getStringList(_vouchersKey) ?? [];
    return cached.map((v) => jsonDecode(v) as Map<String, dynamic>).toList();
  }

  static Future<void> removeVoucher(String ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cached = prefs.getStringList(_vouchersKey) ?? [];
    cached.removeWhere((v) => jsonDecode(v)['ticketId'] == ticketId);
    await prefs.setStringList(_vouchersKey, cached);
  }
}

// ============================================================================
// 2. Low-Connectivity Request Queueing & Background Sync (OfflineQueueManager)
// ============================================================================
class OfflineQueueManager extends ChangeNotifier {
  static const String _queueKey = 'offline_intake_queue';
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  List<QueuedRequest> _queue = [];
  bool _isSyncing = false;
  bool _isOffline = false;

  List<QueuedRequest> get queue => _queue;
  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;

  OfflineQueueManager() {
    _initQueue();
    _checkInitialConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawQueue = prefs.getStringList(_queueKey) ?? [];
    _queue = rawQueue.map((item) => QueuedRequest.fromJson(jsonDecode(item))).toList();
    notifyListeners();
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final rawQueue = _queue.map((req) => jsonEncode(req.toJson())).toList();
    await prefs.setStringList(_queueKey, rawQueue);
    notifyListeners();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = !results.contains(ConnectivityResult.none) && results.isNotEmpty;
    _isOffline = !hasConnection;
    notifyListeners();

    if (hasConnection && _queue.isNotEmpty && !_isSyncing) {
      _flushQueue();
    }
  }

  Future<void> enqueueRequest(
    String rawMessage, {
    String? filePath,
    String? studentName,
    String? studentContact,
  }) async {
    final request = QueuedRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rawMessage: rawMessage,
      filePath: filePath,
      studentName: studentName ?? 'Anonymous',
      studentContact: studentContact ?? '+15550000000',
      timestamp: DateTime.now(),
    );
    
    _queue.add(request);
    await _saveQueue();
    debugPrint('Request queued for offline sync: ${request.id}');
  }

  Future<void> _flushQueue() async {
    if (_queue.isEmpty || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    debugPrint('Flushing ${_queue.length} offline requests...');
    
    final queueCopy = List<QueuedRequest>.from(_queue);

    for (var req in queueCopy) {
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}/intake/web');
        var request = http.MultipartRequest('POST', uri);
        request.headers['x-institution-id'] = ApiConfig.institutionId;
        
        // Match expected backend WebIntakeSchema & multer fields in asyncIntake.ts
        request.fields['message'] = req.rawMessage;
        request.fields['studentName'] = req.studentName ?? 'Anonymous';
        request.fields['studentContact'] = req.studentContact ?? '+15550000000';

        if (req.filePath != null && req.filePath!.isNotEmpty) {
          if (!kIsWeb && File(req.filePath!).existsSync()) {
            request.files.add(
              await http.MultipartFile.fromPath('attachment', req.filePath!),
            );
          }
        }

        // Execute the HTTP request
        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
          try {
            final respData = jsonDecode(response.body) as Map<String, dynamic>;
            if (respData['voucherCode'] != null && respData['ticketId'] != null) {
              await OfflineVoucherStore.cacheVoucher(
                respData['ticketId'].toString(),
                respData['voucherCode'].toString(),
                (respData['amount'] as num?)?.toDouble() ?? 200.0,
              );
            }
          } catch (_) {}

          _queue.removeWhere((item) => item.id == req.id);
          await _saveQueue();
          
          await NotificationService.showNotification(
            title: 'Offline Sync Complete',
            body: 'Your queued emergency request has been successfully submitted.',
          );
        } else {
          debugPrint('Sync request ${req.id} returned HTTP ${response.statusCode}: ${response.body}');
          // Keep item in queue and retry on next connectivity transition
          break;
        }
      } catch (e) {
        debugPrint('Failed to sync request ${req.id}: $e');
        break;
      }
    }

    _isSyncing = false;
    notifyListeners();
  }
}

// ============================================================================
// 3. Push Notification & Real-Time Alert Handler (NotificationService)
// ============================================================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);
            
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationDeepLink(response.payload!);
        }
      },
    );
  }

  static void _handleNotificationDeepLink(String payload) {
    debugPrint('Notification tapped! Deep linking to ticket/voucher: $payload');
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'eduaccess_alerts',
      'Emergency Alerts',
      channelDescription: 'High priority alerts for emergency grants and vouchers.',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.blueAccent,
      playSound: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: 0, 
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  static void simulateIncomingFCMMessage(Map<String, dynamic> fcmData) {
    final type = fcmData['type'];
    final ticketId = fcmData['ticketId'];
    
    if (type == 'VOUCHER_APPROVED') {
      showNotification(
        title: 'Emergency Grant Approved!',
        body: 'Your \$500 emergency voucher is ready. Tap to view QR code.',
        payload: ticketId,
      );
      OfflineVoucherStore.cacheVoucher(ticketId, fcmData['claimCode'] ?? 'UNKNOWN', fcmData['amount'] ?? 0.0);
    } else if (type == 'CRISIS_DISPATCH') {
      showNotification(
        title: 'Campus Safety Dispatched',
        body: 'A safety officer is en route to your location. Stay on the line.',
        payload: ticketId,
      );
    }
  }
}

// ============================================================================
// Example UI Integration (Offline Banner Widget)
// ============================================================================
class OfflineConnectivityBanner extends StatelessWidget {
  const OfflineConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.read<OfflineQueueManager>(),
      builder: (context, _) {
        final offlineManager = context.read<OfflineQueueManager>();
        
        if (!offlineManager.isOffline && offlineManager.queue.isEmpty) {
          return const SizedBox.shrink(); 
        }

        final bool isOffline = offlineManager.isOffline;
        final Color bannerColor = isOffline ? const Color(0xFFD97706) : const Color(0xFF2563EB);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                isOffline
                    ? 'Offline Mode Active — Requests queued safely'
                    : 'Syncing ${offlineManager.queue.length} queued requests to Cloud...',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (offlineManager.queue.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${offlineManager.queue.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
