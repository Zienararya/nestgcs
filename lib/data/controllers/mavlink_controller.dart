import 'package:flutter/material.dart';
import '../models/mavlink_message.dart';

class MavlinkController extends ChangeNotifier {
  final List<MavlinkMessage> _messages = [];
  String _statusMode = '';
  String _statusMessage = '';
  String _currentMode = '';

  List<MavlinkMessage> get messages => _messages;
  String get statusMode => _statusMode;
  String get statusMessage => _statusMessage;
  String get currentMode => _currentMode;

  void addMessage(MavlinkMessage message) {
    // Hapus pesan lama dengan tipe yang sama
    _messages.removeWhere((msg) => msg.type == message.type);
    // Tambahkan pesan baru ke akhir list
    _messages.add(message);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void setStatus(String mode, String message) {
    _statusMode = mode;
    _statusMessage = message;
    notifyListeners();
  }

  void setCurrentMode(String mode) {
    _currentMode = mode;
    notifyListeners();
  }
}
