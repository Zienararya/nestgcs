import 'package:flutter/material.dart';
import '../models/mavlink_message.dart';

class MavlinkController extends ChangeNotifier {
  final List<MavlinkMessage> _messages = [];
  String _statusMode = '';
  String _statusMessage = '';
  String _currentMode = '';
  bool _armed = false;
  int _timeBootMs = 0; // latest SYSTEM_TIME.time_boot_ms
  int? _armedStartBootMs; // time_boot_ms when armed

  // Set from SYSTEM_TIME (time since boot in ms)
  void setTimeBootMs(int value) {
    if (value < 0) return;
    _timeBootMs = value;
    notifyListeners();
  }

  // Derived flight time only counts while armed
  Duration get flightTime {
    if (!_armed || _armedStartBootMs == null) return Duration.zero;
    final delta = _timeBootMs - _armedStartBootMs!;
    if (delta <= 0) return Duration.zero;
    return Duration(milliseconds: delta);
  }

  List<MavlinkMessage> get messages => _messages;
  String get statusMode => _statusMode;
  String get statusMessage => _statusMessage;
  String get currentMode => _currentMode;
  bool get armed => _armed;
  int get timeBootMs => _timeBootMs;

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
      if (value) {
        // starting armed session; mark start if not already
        _armedStartBootMs = _timeBootMs;
      } else {
        // disarmed; keep last values but stop counting
      }
      notifyListeners();
    }
  }
}
