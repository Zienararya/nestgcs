import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../controllers/mavlink_controller.dart';
import '../models/mavlink_message.dart';

class SocketService {
  IO.Socket? _socket;
  bool _isConnected = false;

  void initSocket(MavlinkController controller, {required String backendIP}) {
    final uri = 'http://$backendIP:5000'; // Contoh: 192.168.0.10

    _socket = IO.io(
      uri,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      print("[SOCKET] Connected to $uri");
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      print("[SOCKET] Connect Error: $error");
    });

    _socket!.onError((error) {
      _isConnected = false;
      print("[SOCKET] Error: $error");
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print("[SOCKET] Disconnected");
    });

    _socket!.on('mavlink_data', (data) {
      try {
        final message =
            MavlinkMessage.fromJson(Map<String, dynamic>.from(data));
        controller.addMessage(message);
      } catch (e) {
        print("[SOCKET] Failed to parse MAVLink message: $e");
      }
    });
  }

  /// Send data to server
  void send(String event, dynamic data) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
    } else {
      print("[SOCKET] Cannot send data. Socket is not connected.");
    }
  }

  void dispose() {
    if (_socket != null && _isConnected) {
      _socket!.disconnect();
    }
    _socket?.dispose();
    _isConnected = false;
    print("[SOCKET] Socket disposed");
  }
}
