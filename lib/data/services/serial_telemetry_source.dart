import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:falcon_gcs/data/controllers/mavlink_controller.dart';

/// Minimal SerialTelemetrySource to replace backend socket.
/// TODO: Implement full MAVLink parser integration.
class SerialTelemetrySource {
  final MavlinkController controller;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;

  SerialTelemetrySource(this.controller);

  Future<bool> start({UsbDevice? selectedDevice}) async {
    if (_running) return true;
    final device =
        selectedDevice ?? (await UsbSerial.listDevices()).firstOrNull;
    if (device == null) return false;
    _port = await device.create();
    if (!await _port!.open()) return false;
    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        57600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    _sub = _port!.inputStream?.listen(_onData, onError: (e) {}, onDone: () {});
    _running = true;
    return true;
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    await _port?.close();
    _port = null;
  }

  void _onData(Uint8List data) {
    // Placeholder: Real implementation should parse MAVLink frames and
    // update controller.addMessage(...)
    // For now we ignore incoming data.
  }

  void armDisarm(bool arm) {
    // TODO: build and send MAVLink COMMAND_LONG for component arm/disarm
  }

  void setMode(String mode) {
    // TODO: translate mode string to numeric custom_mode and send SET_MODE
  }

  void calibrateLevel() {
    // TODO: send PREFLIGHT_CALIBRATION command (MAV_CMD_PREFLIGHT_CALIBRATION)
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
