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
    _socket = io.io(uri, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.on('connect', (_) {
      _isConnected = true;
      log('Connected to backend');
    });

    _socket!.on('connect_error', (data) {
      _isConnected = false;
      if (onError != null) onError('Could not connect to backend.');
    });

    _socket!.on('connect_timeout', (data) {
      _isConnected = false;
      if (onError != null) onError('Connection to backend timed out.');
    });

    _socket!.on('mavlink_data', (data) {
      final message = MavlinkMessage.fromJson(Map<String, dynamic>.from(data));
      controller.addMessage(message);
      print('Received from backend: $data');
    });

    _socket!.onAny((event, data) {
      print('Socket event: $event, data: $data');
    });

    _socket!.on('disconnect', (_) {
      _isConnected = false;
      log('Disconnected from backend');
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
