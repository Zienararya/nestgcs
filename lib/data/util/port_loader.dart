import 'serial_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class PortLoader {
  static Future<List<String>> loadPorts() async {
    if (kIsWeb) {
      // On web, just use the factory to get the list
      final serial = createSerialPort();
      return await serial.getAvailablePorts();
    } else {
      // On Android, use flutter_libserialport to list ports
      return SerialPort.availablePorts;
    }
  }

  static dynamic getSerial(String portName) {
    if (kIsWeb) {
      // On web, just call the factory without arguments
      return createSerialPort();
    } else {
      // On Android, create a SerialPort object and pass it to the factory
      final port = SerialPort(portName);
      return createSerialPort(port);
    }
  }
}
