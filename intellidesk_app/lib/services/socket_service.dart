import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/ticket.dart';
import '../config/api_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal() : url = ApiConfig.socketUrl;

  io.Socket? _socket;
  final String url;
  
  Function(Ticket)? onTicketCreated;
  Function(Ticket)? onTicketUpdated;
  Function(bool)? onConnectionStateChanged;

  void connect() {
    if (_socket != null && _socket!.connected) {
      if (onConnectionStateChanged != null) {
        onConnectionStateChanged!(true);
      }
      return;
    }

    _socket?.dispose();

    _socket = io.io(url, io.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(1000)
      .setReconnectionAttempts(999)
      .build()
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected to $url');
      if (onConnectionStateChanged != null) {
        onConnectionStateChanged!(true);
      }
    });

    _socket!.onReconnect((_) {
      debugPrint('Socket reconnected to $url');
      if (onConnectionStateChanged != null) {
        onConnectionStateChanged!(true);
      }
    });

    _socket!.onConnectError((err) {
      debugPrint('Socket connect_error: $err');
      if (onConnectionStateChanged != null) {
        onConnectionStateChanged!(false);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected from $url');
      if (onConnectionStateChanged != null) {
        onConnectionStateChanged!(false);
      }
    });

    _socket!.on('ticket:created', (data) {
      if (data != null) {
        try {
          final ticket = Ticket.fromJson(Map<String, dynamic>.from(data));
          if (onTicketCreated != null) {
            onTicketCreated!(ticket);
          }
        } catch (e) {
          debugPrint('Error parsing ticket:created data: $e');
        }
      }
    });

    _socket!.on('ticket:updated', (data) {
      if (data != null) {
        try {
          final ticket = Ticket.fromJson(Map<String, dynamic>.from(data));
          if (onTicketUpdated != null) {
            onTicketUpdated!(ticket);
          }
        } catch (e) {
          debugPrint('Error parsing ticket:updated data: $e');
        }
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
