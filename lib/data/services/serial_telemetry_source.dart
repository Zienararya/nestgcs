import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:falcon_gcs/data/controllers/mavlink_controller.dart';
import 'package:falcon_gcs/data/models/mavlink_message.dart';

/// Very lightweight MAVLink v1/v2 parser for a small subset of message IDs
/// needed by the current UI. Not a full implementation; focuses on:
///  - HEARTBEAT (0)
///  - SYS_STATUS (1)
///  - GLOBAL_POSITION_INT (33)
///  - ATTITUDE (30)
///  - GPS_RAW_INT (24)
///  - VFR_HUD (74)
///  - SCALED_PRESSURE (29)
/// Only little-endian. Assumes link is not signing frames.
class SerialTelemetrySource {
  final MavlinkController controller;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;
  int _baud = 0; // actual baud used
  int framesOk = 0;
  int framesCrcFail = 0;
  int bytesReceived = 0;
  final List<int> _recentMsgIds = [];
  int? _sysId; // discovered system id
  int? _compId; // discovered component id
  bool _streamsRequested = false; // ensure we only request once
  Timer? _hbTimer; // periodic GCS heartbeat
  Timer? _intervalFallbackTimer; // fallback timer to request message intervals
  bool _intervalsRequested =
      false; // guard so we only send interval commands once

  // Parser state
  final List<int> _buffer = [];
  static const int stxV1 = 0xFE; // MAVLink v1
  static const int stxV2 = 0xFD; // MAVLink v2
  // Optional external logging callback (type, data)
  void Function(String type, Map<String, dynamic> data)? onDecoded;
  int _crcFailCount = 0; // limited debug counter

  // Extra CRC table subset (common.xml) – add more ids here if needed
  static const Map<int, int> _extraCrc = {
    0: 50, // HEARTBEAT
    1: 124, // SYS_STATUS
    2: 137, // SYSTEM_TIME
    11: 89, // SET_MODE
    24: 24, // GPS_RAW_INT
    29: 115, // SCALED_PRESSURE
    30: 39, // ATTITUDE
    33: 104, // GLOBAL_POSITION_INT
    66: 148, // REQUEST_DATA_STREAM
    74: 20, // VFR_HUD
    76: 152, // COMMAND_LONG
  };

  SerialTelemetrySource(this.controller);

  // Debug/stat getters
  int get baud => _baud;
  int get okFrames => framesOk;
  int get crcFailFrames => framesCrcFail;
  int get rxBytes => bytesReceived;
  List<int> get recentMsgIds => List.unmodifiable(_recentMsgIds);

  Future<bool> start({UsbDevice? selectedDevice}) async {
    if (_running) return true;
    final device =
        selectedDevice ?? (await UsbSerial.listDevices()).firstOrNull;
    if (device == null) return false;
    _port = await device.create();
    if (!await _port!.open()) return false;
    await _port!.setDTR(true);
    await _port!.setRTS(true);
    // Try common Pixhawk USB baud rates: 115200 first, then 57600
    final baudCandidates = [115200, 57600];
    bool configured = false;
    for (final b in baudCandidates) {
      try {
        await _port!.setPortParameters(
            b, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
        _baud = b;
        configured = true;
        break;
      } catch (_) {}
    }
    if (!configured) {
      await _port?.close();
      _port = null;
      return false;
    }
    // Reset runtime state counters for fresh session
    framesOk = 0;
    framesCrcFail = 0;
    bytesReceived = 0;
    _recentMsgIds.clear();
    _streamsRequested = false;
    _intervalsRequested = false;
    _sysId = null;
    _compId = null;
    _sub = _port!.inputStream?.listen(_onData, onError: (e) {}, onDone: () {});
    _running = true;
    _startHeartbeat();
    _startIntervalFallbackWatcher();
    return true;
  }

  Future<void> stop() async {
    _running = false;
    _hbTimer?.cancel();
    _hbTimer = null;
    _intervalFallbackTimer?.cancel();
    _intervalFallbackTimer = null;
    controller.setStatus('info', 'serial berhenti');
    await _sub?.cancel();
    _sub = null;
    await _port?.close();
    _port = null;
  }

  void _onData(Uint8List data) {
    // Append incoming bytes then try to parse frames
    bytesReceived += data.length;
    for (final b in data) {
      _buffer.add(b);
    }
    _drain();
  }

  void _drain() {
    // Keep attempting to parse while enough bytes exist
    while (true) {
      if (_buffer.length < 8) return; // minimal header + checksum
      // Seek STX
      int idx = _buffer.indexWhere((b) => b == stxV1 || b == stxV2);
      if (idx < 0) {
        _buffer.clear();
        return;
      }
      if (idx > 0) {
        _buffer.removeRange(0, idx);
      }
      if (_buffer.isEmpty) return;
      final stx = _buffer[0];
      if (stx == stxV1) {
        if (_buffer.length < 6)
          return; // stx + len + seq + sys + comp + msgid + payload + 2 checksum
        final payloadLen = _buffer[1];
        final needed =
            6 + payloadLen + 2; // header(6 inc STX) + payload + checksum2
        if (_buffer.length < needed) return; // wait more
        final frame = _buffer.sublist(0, needed);
        // compute checksum over (len,seq,sys,comp,msgid,payload)
        int crc = _x25(frame.sublist(1, 1 + 5 + payloadLen));
        final msgId = frame[5];
        final extra = _extraCrc[msgId];
        if (extra != null) {
          crc = _crcAccumulate(crc, extra);
        }
        final cka = frame[needed - 2];
        final ckb = frame[needed - 1];
        if (cka == (crc & 0xFF) && ckb == ((crc >> 8) & 0xFF)) {
          _handleFrameV1(frame);
        } else {
          if (_crcFailCount < 10) {
            _crcFailCount++;
            // Optional: print debug if needed
            // debugPrint('CRC FAIL V1 id=$msgId calc=${crc.toRadixString(16)} got=${cka.toRadixString(16)} ${ckb.toRadixString(16)}');
          }
          framesCrcFail++;
        }
        _buffer.removeRange(0, needed);
      } else if (stx == stxV2) {
        if (_buffer.length < 10)
          return; // stx + len(1) + incompat(1)+ compat(1)+ seq + sys + comp + msgid(3) + ...
        final payloadLen = _buffer[1];
        final incompatFlags = _buffer[2];
        final hasSignature =
            (incompatFlags & 0x01) != 0; // MAVLINK_IFLAG_SIGNED
        final headerLen = 10; // stx + 9 following header bytes
        final checksumLen = 2;
        final signatureLen = hasSignature ? 13 : 0;
        final needed = headerLen + payloadLen + checksumLen + signatureLen;
        if (_buffer.length < needed) return;
        final forCrc =
            _buffer.sublist(0, headerLen + payloadLen); // header+payload
        // compute checksum over bytes 1..(headerLen+payloadLen-1)
        int crc = _x25(forCrc.sublist(1, 1 + 9 + payloadLen));
        final msgId = forCrc[7] | (forCrc[8] << 8) | (forCrc[9] << 16);
        final extra = _extraCrc[msgId];
        if (extra != null) {
          crc = _crcAccumulate(crc, extra);
        }
        final cka = _buffer[headerLen + payloadLen];
        final ckb = _buffer[headerLen + payloadLen + 1];
        if (cka == (crc & 0xFF) && ckb == ((crc >> 8) & 0xFF)) {
          // pass frame excluding signature to handler
          _handleFrameV2(
              _buffer.sublist(0, headerLen + payloadLen + checksumLen));
        } else {
          if (_crcFailCount < 10) {
            _crcFailCount++;
          }
          framesCrcFail++;
        }
        _buffer.removeRange(0, needed);
      } else {
        _buffer.removeAt(0);
      }
    }
  }

  int _x25(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc = _crcAccumulate(crc, b);
    }
    return crc;
  }

  int _crcAccumulate(int crc, int b) {
    int tmp = b ^ (crc & 0xFF);
    tmp ^= (tmp << 4) & 0xFF;
    return ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF;
  }

  // -------------------- Frame Handling --------------------
  void _handleFrameV1(List<int> frame) {
    final payloadLen = frame[1];
    final msgId = frame[5];
    _sysId ??= frame[3];
    _compId ??= frame[4];
    final payload = frame.sublist(6, 6 + payloadLen);
    _decodeMessage(msgId, payload);
    framesOk++;
    _pushRecent(msgId);
  }

  void _handleFrameV2(List<int> frame) {
    final payloadLen = frame[1];
    final msgId = frame[7] | (frame[8] << 8) | (frame[9] << 16);
    _sysId ??= frame[5];
    _compId ??= frame[6];
    final payload = frame.sublist(10, 10 + payloadLen);
    _decodeMessage(msgId, payload);
    framesOk++;
    _pushRecent(msgId);
  }

  // Decode subset of MAVLink messages; payload layouts per common.xml
  void _decodeMessage(int msgId, List<int> p) {
    try {
      switch (msgId) {
        case 0: // HEARTBEAT
          if (p.length >= 9) {
            final customMode = _u32(p, 0);
            final type = p[4];
            final autopilot = p[5];
            final baseMode = p[6];
            final systemStatus = p[7];
            final mavVersion = p[8];
            final armed = (baseMode & 0x80) != 0; // MAV_MODE_FLAG_SAFETY_ARMED
            controller.setArmed(armed);
            controller.setCurrentMode(_modeFromCustom(customMode));
            if (!_streamsRequested) {
              controller.setStatus('info', 'heartbeat diterima (sys=$_sysId)');
            }
            controller.addMessage(MavlinkMessage(type: 'HEARTBEAT', data: {
              'custom_mode': customMode,
              'type': type,
              'autopilot': autopilot,
              'base_mode': baseMode,
              'system_status': systemStatus,
              'mavlink_version': mavVersion,
              'armed': armed,
            }));
            // Minta stream setelah pertama kali heartbeat diterima
            if (!_streamsRequested && _sysId != null) {
              _requestStandardStreams();
            }
            onDecoded?.call('HEARTBEAT', {
              'custom_mode': customMode,
              'type': type,
              'autopilot': autopilot,
              'base_mode': baseMode,
              'system_status': systemStatus,
              'mavlink_version': mavVersion,
            });
          }
          break;
        case 2: // SYSTEM_TIME
          if (p.length >= 12) {
            final timeBootMs = _u32(p, 8); // last 4 bytes
            controller.setTimeBootMs(timeBootMs);
            controller.addMessage(MavlinkMessage(type: 'SYSTEM_TIME', data: {
              'time_boot_ms': timeBootMs,
            }));
            onDecoded?.call('SYSTEM_TIME', {'time_boot_ms': timeBootMs});
          }
          break;
        case 1: // SYS_STATUS
          if (p.length >= 31) {
            final dropRate = _u16(p, 14); // comm drop rate
            final batteryRemaining = p[30];
            controller.addMessage(MavlinkMessage(type: 'SYS_STATUS', data: {
              'drop_rate_comm': dropRate,
              'battery_remaining': batteryRemaining,
            }));
            onDecoded?.call('SYS_STATUS', {
              'drop_rate_comm': dropRate,
              'battery_remaining': batteryRemaining,
            });
          }
          break;
        case 24: // GPS_RAW_INT
          if (p.length >= 30) {
            final fixTime = _u64(p, 0);
            final lat = _i32(p, 8);
            final lon = _i32(p, 12);
            final alt = _i32(p, 16);
            final eph = _u16(p, 20);
            final satellites = p[29];
            controller.addMessage(MavlinkMessage(type: 'GPS_RAW_INT', data: {
              'time_usec': fixTime,
              'lat': lat,
              'lon': lon,
              'alt': alt,
              'eph': eph,
              'satellites_visible': satellites,
            }));
            onDecoded?.call('GPS_RAW_INT', {
              'time_usec': fixTime,
              'lat': lat,
              'lon': lon,
              'alt': alt,
              'eph': eph,
              'satellites_visible': satellites,
            });
          }
          break;
        case 29: // SCALED_PRESSURE
          if (p.length >= 14) {
            final pressAbs = _i16(p, 0) / 100.0; // hPa
            final pressDiff = _i16(p, 2) / 100.0;
            controller
                .addMessage(MavlinkMessage(type: 'SCALED_PRESSURE', data: {
              'press_abs': pressAbs,
              'press_diff': pressDiff,
            }));
            onDecoded?.call('SCALED_PRESSURE', {
              'press_abs': pressAbs,
              'press_diff': pressDiff,
            });
          }
          break;
        case 30: // ATTITUDE
          if (p.length >= 28) {
            final roll = _f32(p, 0);
            final pitch = _f32(p, 4);
            final yaw = _f32(p, 8);
            controller.addMessage(MavlinkMessage(type: 'ATTITUDE', data: {
              'roll': roll,
              'pitch': pitch,
              'yaw': yaw,
            }));
            onDecoded?.call('ATTITUDE', {
              'roll': roll,
              'pitch': pitch,
              'yaw': yaw,
            });
          }
          break;
        case 33: // GLOBAL_POSITION_INT
          if (p.length >= 28) {
            final lat = _i32(p, 4);
            final lon = _i32(p, 8);
            final alt = _i32(p, 12);
            final hdg = _u16(p, 26);
            controller
                .addMessage(MavlinkMessage(type: 'GLOBAL_POSITION_INT', data: {
              'lat': lat,
              'lon': lon,
              'alt': alt,
              'hdg': hdg,
            }));
            onDecoded?.call('GLOBAL_POSITION_INT', {
              'lat': lat,
              'lon': lon,
              'alt': alt,
              'hdg': hdg,
            });
          }
          break;
        case 74: // VFR_HUD
          if (p.length >= 20) {
            final airspeed = _f32(p, 0);
            final groundspeed = _f32(p, 4);
            final heading = _i16(p, 16);
            controller.addMessage(MavlinkMessage(type: 'VFR_HUD', data: {
              'airspeed': airspeed,
              'groundspeed': groundspeed,
              'heading': heading,
            }));
            onDecoded?.call('VFR_HUD', {
              'airspeed': airspeed,
              'groundspeed': groundspeed,
              'heading': heading,
            });
          }
          break;
        default:
          // Ignore other messages silently
          break;
      }
    } catch (e) {
      // swallow parsing errors for robustness
    }
  }

  void _pushRecent(int id) {
    _recentMsgIds.add(id);
    if (_recentMsgIds.length > 15) {
      _recentMsgIds.removeRange(0, _recentMsgIds.length - 15);
    }
  }

  String _modeFromCustom(int custom) {
    // Simplified mapping for ArduCopter (custom_mode corresponds directly)
    // Provide only subset used by UI
    const known = {
      0: 'STABILIZE',
      2: 'ALT_HOLD',
      3: 'AUTO',
      4: 'GUIDED',
      5: 'LOITER',
      6: 'RTL',
      9: 'CIRCLE',
      11: 'LAND',
      13: 'SPORT',
      16: 'POSHOLD'
    };
    return known[custom] ?? custom.toString();
  }

  // ==================== Command Sending ====================
  void armDisarm(bool arm) {
    // Build COMMAND_LONG with MAV_CMD_COMPONENT_ARM_DISARM (400)
    _sendCommandLong(400, [arm ? 1.0 : 0.0, 0, 0, 0, 0, 0, 0]);
  }

  void setMode(String mode) {
    // For ArduCopter set custom_mode field in SET_MODE (11)
    final custom = _customFromMode(mode);
    if (custom == null) return;
    _sendSetMode(custom);
  }

  void calibrateLevel() {
    // MAV_CMD_PREFLIGHT_CALIBRATION = 241 (param1 accel, param2 mag, param5 ground pressure, param6 radio)
    _sendCommandLong(241, [1, 0, 0, 0, 0, 0, 0]);
    controller.setStatus('info', 'kalibrasi level dikirim');
  }

  int? _customFromMode(String mode) {
    final map = {
      'STABILIZE': 0,
      'ALT_HOLD': 2,
      'AUTO': 3,
      'GUIDED': 4,
      'LOITER': 5,
      'RTL': 6,
      'CIRCLE': 9,
      'LAND': 11,
      'SPORT': 13,
      'POSHOLD': 16,
    };
    return map[mode.toUpperCase()];
  }

  void _sendSetMode(int customMode) {
    // MAVLink v1 SET_MODE (msg id 11): payload 6 bytes
    final payload = <int>[];
    payload.add(_sysId ?? 0); // target system
    payload.add(0); // base_mode (let autopilot manage)
    payload.addAll(_u32le(customMode));
    _writeMavlinkV1(11, payload);
  }

  void _sendCommandLong(int command, List<double> params) {
    // COMMAND_LONG (id 76) payload 33 bytes: 7*float32 + target_system + target_component + command(2) + confirmation + 2 bytes padding? (Simplified)
    final payload = BytesBuilder();
    for (int i = 0; i < 7; i++) {
      payload.add(_f32le(i < params.length ? params[i] : 0));
    }
    payload.add([_sysId ?? 0]); // target system
    payload.add([_compId ?? 0]); // target component
    payload.add(_u16le(command));
    payload.add([0]); // confirmation
    final bytes = payload.toBytes();
    _writeMavlinkV1(76, bytes);
  }

  // Basic v1 frame writer (no signing)
  int _seq = 0;
  void _writeMavlinkV1(int msgId, List<int> payload) {
    if (_port == null) return;
    final len = payload.length;
    final sys = 255; // typical GCS id
    final comp = 190; // GCS component id
    final core = <int>[len, _seq & 0xFF, sys, comp, msgId];
    core.addAll(payload);
    int crc = _x25(core); // without STX
    final extra = _extraCrc[msgId];
    if (extra != null) {
      crc = _crcAccumulate(crc, extra);
    }
    final frame = <int>[stxV1];
    frame.addAll(core);
    frame.add(crc & 0xFF);
    frame.add((crc >> 8) & 0xFF);
    _seq = (_seq + 1) & 0xFF;
    _port!.write(Uint8List.fromList(frame));
  }

  // ==================== Helpers ====================
  int _u16(List<int> b, int o) => b[o] | (b[o + 1] << 8);
  int _i16(List<int> b, int o) {
    int v = _u16(b, o);
    if (v & 0x8000 != 0) v = v - 0x10000;
    return v;
  }

  int _u32(List<int> b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
  int _i32(List<int> b, int o) {
    int v = _u32(b, o);
    if (v & 0x80000000 != 0) v = v - 0x100000000;
    return v;
  }

  int _u64(List<int> b, int o) {
    int lo = _u32(b, o);
    int hi = _u32(b, o + 4);
    return (hi << 32) | lo;
  }

  double _f32(List<int> b, int o) {
    final bytes = b.sublist(o, o + 4);
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    return bd.getFloat32(0, Endian.little);
  }

  List<int> _u32le(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  List<int> _u16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  List<int> _f32le(double d) {
    final bd = ByteData(4);
    bd.setFloat32(0, d, Endian.little);
    return [bd.getUint8(0), bd.getUint8(1), bd.getUint8(2), bd.getUint8(3)];
  }

  // ------------------- Stream Requests -------------------
  void _sendRequestDataStream(int streamId, int rateHz) {
    if (_sysId == null) return; // but we should have after first heartbeat
    // REQUEST_DATA_STREAM (id 66) layout (MAVLink v1 common):
    // rate (uint16), target_system (uint8), target_component (uint8), stream_id (uint8), start_stop (uint8)
    final payload = <int>[];
    payload.addAll(_u16le(rateHz));
    payload.add(_sysId!);
    payload.add(_compId ?? 0);
    payload.add(streamId);
    payload.add(1); // start
    _writeMavlinkV1(66, payload);
  }

  void _requestStandardStreams() {
    // EXTENDED_STATUS(2), POSITION(6), EXTRA1(10=ATTITUDE), EXTRA2(11=VFR_HUD)
    _sendRequestDataStream(2, 2);
    _sendRequestDataStream(6, 2);
    _sendRequestDataStream(10, 10);
    _sendRequestDataStream(11, 5);
    _streamsRequested = true;
    controller.setStatus('info', 'meminta data stream');
  }

  void _startHeartbeat() {
    _hbTimer?.cancel();
    _hbTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      _sendGcsHeartbeat();
    });
  }

  void _sendGcsHeartbeat() {
    // HEARTBEAT payload layout (9 bytes): custom_mode(4) | type | autopilot | base_mode | system_status | mavlink_version
    final payload = <int>[];
    payload.addAll(_u32le(0)); // custom_mode
    payload.add(6); // type = MAV_TYPE_GCS (6)
    payload.add(8); // autopilot = MAV_AUTOPILOT_INVALID
    payload.add(0); // base_mode
    payload.add(0); // system_status
    payload.add(3); // mavlink version (3 for v2)
    _writeMavlinkV1(0, payload);
  }

  // Fallback interval request if only heartbeat arrives
  void _startIntervalFallbackWatcher() {
    _intervalFallbackTimer?.cancel();
    _intervalFallbackTimer = Timer(const Duration(seconds: 3), () {
      if (_intervalsRequested) return;
      final hasOther = controller.messages.any((m) => m.type != 'HEARTBEAT');
      if (!hasOther && _sysId != null) {
        _requestMessageIntervals();
      }
    });
  }

  void _requestMessageIntervals() {
    // MAV_CMD_SET_MESSAGE_INTERVAL = 511
    final ids = [33, 30, 74, 24, 29, 1, 2];
    for (final id in ids) {
      final intervalUs = _intervalForId(id);
      _sendCommandLong(
          511, [id.toDouble(), intervalUs.toDouble(), 0, 0, 0, 0, 0]);
    }
    _intervalsRequested = true;
    controller.setStatus('info', 'meminta interval message');
  }

  double _intervalForId(int id) {
    switch (id) {
      case 30:
        return 100000; // ATTITUDE 10Hz
      case 33:
        return 200000; // GLOBAL_POSITION_INT 5Hz
      case 74:
        return 200000; // VFR_HUD 5Hz
      case 24:
        return 500000; // GPS_RAW_INT 2Hz
      case 29:
        return 200000; // SCALED_PRESSURE 5Hz
      case 1:
        return 500000; // SYS_STATUS 2Hz
      case 2:
        return 1000000; // SYSTEM_TIME 1Hz
      default:
        return 500000;
    }
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
