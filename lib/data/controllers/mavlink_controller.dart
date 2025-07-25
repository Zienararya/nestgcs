import 'package:flutter/material.dart';
import '../models/mavlink_message.dart';

class MavlinkController extends ChangeNotifier {
  final List<MavlinkMessage> _messages = [];

  List<MavlinkMessage> get messages => _messages;

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
}
