import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../controllers/mavlink_controller.dart';
import '../models/mavlink_message.dart';

class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;

  void initSocket(MavlinkController controller, {required String backendIP}) {
    final uri = 'http://$backendIP:5000';
    _socket = io.io(uri, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.on('connect', (_) {
      _isConnected = true;
      log('Connected to backend');
    });

    _socket!.on('mavlink_data', (data) {
      final message = MavlinkMessage.fromJson(Map<String, dynamic>.from(data));
      controller.addMessage(message);
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
