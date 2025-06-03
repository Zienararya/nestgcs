import 'package:flutter/material.dart';
import '../models/mavlink_message.dart';

class MavlinkController extends ChangeNotifier {
  final List<MavlinkMessage> _messages = [];

  List<MavlinkMessage> get messages => _messages;

  void addMessage(MavlinkMessage message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
