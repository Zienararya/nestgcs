import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../controllers/mavlink_controller.dart';
import '../models/mavlink_message.dart';

class SocketService {
  io.Socket? _socket;

  void initSocket(
    MavlinkController controller, {
    required String backendIP,
    void Function(String error)? onError,
    VoidCallback? onConnected,
    void Function(String reason)? onDisconnected,
    void Function(int attempt)? onReconnecting,
    void Function(int attempt)? onReconnected,
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
      final transportName = manager.engine?.transport?.name;
      log('Socket connected. id=${_socket!.id} transport=$transportName');
      if (onConnected != null) onConnected();
    });

    _socket!.on('error', (data) => log('Socket error: $data'));

    _socket!.on('connect_error', (data) {
      log('Connect error: $data');
      if (onError != null) onError('Could not connect to backend.');
    });

    _socket!.on('connect_timeout', (data) {
      log('Connect timeout: $data');
      if (onError != null) onError('Connection to backend timed out.');
    });

    _socket!.on('reconnect_attempt', (attempt) {
      log('Reconnecting attempt #$attempt');
      if (onReconnecting != null) onReconnecting(attempt is int ? attempt : 0);
    });
    _socket!.on('reconnect_failed', (_) {
      log('Reconnection failed');
    });
    _socket!.on('reconnect_error', (e) {
      log('Reconnection error: $e');
    });
    _socket!.on('reconnect', (attempt) {
      log('Reconnected after $attempt attempts');
      if (onReconnected != null) onReconnected(attempt is int ? attempt : 0);
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

    _socket!.on('status', (data) {
      try {
        if (data is Map) {
          final mode = data['mode']?.toString() ?? '';
          final msg = data['message']?.toString() ?? '';
          controller.setStatus(mode, msg);
          log('Status update: mode=$mode message=$msg');
        } else {
          log('Status event non-map: $data');
        }
      } catch (e) {
        log('Error parsing status event: $e data=$data');
      }
    });

    // Listen for mode updates from backend
    _socket!.on('mode_update', (data) {
      try {
        if (data is Map && data['mode'] is String) {
          controller.setCurrentMode(data['mode'] as String);
        } else if (data is String) {
          controller.setCurrentMode(data);
        }
      } catch (_) {}
    });

    // Listen for arming state updates from backend heartbeat or command ack
    _socket!.on('arming_update', (data) {
      try {
        if (data is Map && data['armed'] is bool) {
          controller.setArmed(data['armed'] as bool);
          log('Arming update received: ${data['armed']}');
        }
      } catch (e) {
        log('Error parsing arming_update: $e data=$data');
      }
    });

    _socket!.onAny((event, data) {
      // Debug hook if needed
    });

    _socket!.on('disconnect', (reason) {
      log('Disconnected: reason=$reason');
      if (onDisconnected != null) onDisconnected(reason?.toString() ?? '');
    });

    _socket!.connect();
  }

  void send(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void setMode(String modeName) {
    final s = _socket;
    if (s == null) return;
    try {
      s.emit('set_mode', {'mode': modeName});
    } catch (_) {}
  }

  void setArming(bool arm) {
    final s = _socket;
    if (s == null) return;
    try {
      s.emit('set_arming', {'arm': arm});
    } catch (_) {}
  }

  void dispose() {
    _socket?.dispose();
  }
}
