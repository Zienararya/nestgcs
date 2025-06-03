import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'serial_interface.dart';

class SerialPlatformImpl implements SerialInterface {
  final SerialPort port;

  SerialPlatformImpl(this.port);

  @override
  Future<List<String>> getAvailablePorts() async {
    return SerialPort.availablePorts;
  }

  @override
  Future<void> open() async {
    if (!port.openReadWrite()) {
      throw Exception('Failed to open port');
    }
  }

  @override
  Future<void> write(Uint8List data) async {
    port.write(data);
  }

  @override
  Future<List<int>> read() async {
    return port.read(port.bytesAvailable);
  }

  @override
  Future<void> close() async {
    port.close();
  }

  // @override
  // Future<List<String>> getAvailablePorts() async {
  //   return SerialPort.availablePorts;
  // }
}
