import 'dart:async';
import 'dart:js_interop';
import 'package:serial/serial.dart';
import 'dart:typed_data';
import 'serial_interface.dart';
import 'package:web/web.dart' as web;

class SerialWeb implements SerialInterface {
  SerialPort? _port;
  bool _keepReading = true;
  final _received = <Uint8List>[];

  @override
  Future<List<String>> getAvailablePorts() async {
    // Web Serial API does not provide a way to list ports before user interaction.
    // You can return an empty list or a placeholder.
    return ['COM4', 'COM5', '/dev/ttyUSB0', '/dev/ttyUSB1'];
  }

  @override
  Future<void> open() async {
    await _port?.close().toDart;
    final port = await web.window.navigator.serial.requestPort().toDart;

    await port.open(baudRate: 9600).toDart;

    _port = port;
    _keepReading = true;

    read();
  }

  @override
  Future<void> write(Uint8List data) async {
    if (data.isEmpty) {
      return;
    }

    final port = _port;

    if (port == null) {
      return;
    }

    final writer = port.writable?.getWriter();

    if (writer != null) {
      await writer.write(data.toJS).toDart;
      writer.releaseLock();
    }
  }

  @override
  Future<List<int>> read() async {
    final port = _port;
    if (port == null) {
      return [];
    }
    while (port.readable != null && _keepReading) {
      final reader =
          port.readable!.getReader() as web.ReadableStreamDefaultReader;

      while (_keepReading) {
        try {
          final result = await reader.read().toDart;

          if (result.done) {
            ///Reader has been canceled.
            break;
          }

          final value = result.value;
          if (value != null && value.isA<JSUint8Array>()) {
            final data = value as JSUint8Array;
            _received.add(data.toDart);
          }
        } catch (e) {
          print(e);
        } finally {
          reader.releaseLock();
        }
      }

      reader.releaseLock();
    }
    // Return the concatenated received data as a single List<int>
    return _received.expand((e) => e).toList();
  }

  @override
  Future<void> close() async {
    _port?.close();
  }
}
