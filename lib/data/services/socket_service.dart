import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../controllers/mavlink_controller.dart';
import '../models/mavlink_message.dart';

class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;

  void initSocket(
    MavlinkController controller, {
    required String backendIP,
    void Function(String error)? onError,
  }) {
    final uri = 'http://$backendIP:5000';

    // Direct options map (avoids nullable options edits)
    _socket = io.io(
      uri,
      {
        'transports': ['websocket', 'polling'],
        'path': '/socket.io/',
        'timeout': 20000, // connect timeout ms
        'reconnection': true,
        'reconnectionAttempts': 0, // unlimited
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'autoConnect': false,
      },
    );

    final manager = _socket!.io;

    _socket!.on('connect', (_) {
      _isConnected = true;
      final transportName = manager.engine?.transport?.name;
      log('Socket connected. id=${_socket!.id} transport=$transportName');
    });

    _socket!.on('error', (data) => log('Socket error: $data'));

    _socket!.on('connect_error', (data) {
      _isConnected = false;
      log('Connect error: $data');
      if (onError != null) onError('Could not connect to backend.');
    });

    _socket!.on('connect_timeout', (data) {
      _isConnected = false;
      log('Connect timeout: $data');
      if (onError != null) onError('Connection to backend timed out.');
    });

    _socket!.on('reconnect_attempt',
        (attempt) => log('Reconnecting attempt #$attempt'));
    _socket!.on('reconnect_failed', (_) => log('Reconnection failed'));
    _socket!.on('reconnect_error', (e) => log('Reconnection error: $e'));
    _socket!.on('reconnect', (attempt) {
      _isConnected = true;
      log('Reconnected after $attempt attempts');
    });

    _socket!.on('ping', (_) => log('ping'));
    _socket!.on('pong', (latency) => log('pong latency=${latency}ms'));

    _socket!.on('mavlink_data', (data) {
      try {
        final message =
            MavlinkMessage.fromJson(Map<String, dynamic>.from(data));
        controller.addMessage(message);
      } catch (e) {
        log('Parse mavlink_data error: $e data=$data');
      }
    });

    _socket!.onAny((event, data) {
      // Debug hook if needed
    });

    _socket!.on('disconnect', (reason) {
      _isConnected = false;
      log('Disconnected: reason=$reason');
    });

    _socket!.connect();
  }

  void send(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _socket?.dispose();
  }
}
