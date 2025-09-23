import 'package:flutter/material.dart';
import '../models/mavlink_message.dart';

class MavlinkController extends ChangeNotifier {
  final List<MavlinkMessage> _messages = [];
  String _statusMode = '';
  String _statusMessage = '';
  String _currentMode = '';
  bool _armed = false;

  List<MavlinkMessage> get messages => _messages;
  String get statusMode => _statusMode;
  String get statusMessage => _statusMessage;
  String get currentMode => _currentMode;
  bool get armed => _armed;

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

  void setArmed(bool value) {
    if (_armed != value) {
      _armed = value;
      notifyListeners();
    }
  }
}
