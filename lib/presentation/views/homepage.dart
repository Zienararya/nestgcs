import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:falcon_gcs/data/controllers/mavlink_controller.dart';
import 'package:falcon_gcs/data/services/socket_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:falcon_gcs/presentation/component/alert.dart';
import 'package:falcon_gcs/presentation/component/navbar.dart';
import 'package:falcon_gcs/presentation/component/altimeter.dart';
import 'package:falcon_gcs/data/models/mavlink_message.dart';
import 'dart:math' as math; // added for compass rotation

class Homepage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Homepage({super.key, required this.cameras});

  @override
  State<Homepage> createState() => _HomepageState();
}

// ======================
//  Homepage State Class
// ======================
class _HomepageState extends State<Homepage> {
  // ======================
  //  State Variables
  // ======================
  MapController? mapController;
  double _currentZoom = 15.0;
  late CameraController _cameraController;
  Future<void>? _initializeControllerFuture;
  final LatLng _center = const LatLng(-7.276716204463224, 112.79310750593704);
  String planePinLayerId = 'plane_pin';
  // Supported modes (match backend map names, e.g., ArduCopter)
  static const List<String> flightmode = <String>[
    'STABILIZE',
    'ALT_HOLD',
    'LOITER',
    'GUIDED',
    'AUTO',
    'RTL',
    'CIRCLE',
    'LAND',
    'DRIFT',
    'SPORT',
    'FLIP',
    'AUTOTUNE',
    'POSHOLD',
    'BRAKE',
    'THROW',
    'AVOID_ADSB',
    'GUIDED_NOGPS',
  ];
  static String flightmodeValue = flightmode.first;
  final TextEditingController ipAddress = TextEditingController();
  bool? isArming;
  bool showAlert = false;
  Color alertColor = Colors.red;
  String alertTitle = "";
  String alertDescription = "";
  late SocketService socketService;
  bool isConnected = false;
  bool showInfoPanel = false;
  double? _lastLat;
  double? _lastLon;
  // Track history
  final List<LatLng> _track = [];
  final Distance _distance = const Distance();

  // Helper aman untuk angka
  T safeNum<T extends num>(dynamic v, T fallback) {
    if (v == null) return fallback;
    if (v is num && (v.isNaN || v.isInfinite)) return fallback;
    return v as T;
  }

  // ======================
  //  Lifecycle Methods
  // ======================
  // init function(function run when apps started)
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    socketService = SocketService();
    mapController = MapController();
  }

// turn off camera
  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // ======================
  //  Camera Functions
  // ======================
  void _initializeCamera() {
    if (widget.cameras.isNotEmpty) {
      _cameraController = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
      );
      _initializeControllerFuture = _cameraController.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  // ======================
  //  UI Toggle Functions
  // ======================
  void toggleInfoPanel() {
    setState(() {
      showInfoPanel = !showInfoPanel;
      _initializeCamera();
    });
  }

  // ======================
  //  Backend Connection
  // ======================
  void connectToBackend() {
    final controller = Provider.of<MavlinkController>(context, listen: false);
    final ip = ipAddress.text.trim();

    if (isConnected) {
      socketService.dispose();
      setState(() {
        isConnected = false;
        alertColor = Colors.orange;
        alertTitle = "Disconnected";
        alertDescription = "Disconnected from backend.";
        showAlert = true;
      });
      return;
    }

    if (ip.isEmpty) {
      setState(() {
        alertColor = Colors.red;
        alertTitle = "Error";
        alertDescription = "IP Address cannot be empty!";
        showAlert = true;
      });
      return;
    }
    socketService.initSocket(
      controller,
      backendIP: ip,
      onError: (error) {
        setState(() {
          alertColor = Colors.red;
          alertTitle = "Connection Failed";
          alertDescription = error;
          showAlert = true;
          isConnected = false;
        });
      },
      onConnected: () {
        if (!mounted) return;
        setState(() {
          alertColor = Colors.green;
          alertTitle = "Connected";
          alertDescription = "Connected to backend at $ip";
          showAlert = true;
          isConnected = true;
        });
      },
      onDisconnected: (reason) {
        if (!mounted) return;
        setState(() {
          alertColor = Colors.orange;
          alertTitle = "Disconnected";
          alertDescription = reason.isNotEmpty ? reason : "Connection lost";
          showAlert = true;
          isConnected = false;
        });
      },
      onReconnecting: (attempt) {
        if (!mounted) return;
        setState(() {
          alertColor = Colors.orange;
          alertTitle = "Reconnecting";
          alertDescription = "Attempt #$attempt";
          showAlert = true;
        });
      },
      onReconnected: (attempt) {
        if (!mounted) return;
        setState(() {
          alertColor = Colors.green;
          alertTitle = "Reconnected";
          alertDescription = "Restored after $attempt attempts";
          showAlert = true;
          isConnected = true;
        });
      },
    );
    setState(() {
      alertColor = Colors.green;
      alertTitle = "Connecting";
      alertDescription = "Connecting to backend at $ip";
      showAlert = true;
    });
  }

  // ======================
  //  Arming/Disarm Button
  // ======================
  void _toggleArming() {
    final controller = Provider.of<MavlinkController>(context, listen: false);
    final target = !(controller.armed);
    socketService.setArming(target);
    setState(() {
      alertColor = target ? Colors.red : Colors.green;
      alertTitle = target ? 'Arming...' : 'Disarming...';
      alertDescription =
          target ? 'Mengirim perintah ARM' : 'Mengirim perintah DISARM';
      showAlert = true;
    });
  }

  // ======================
  //  Alert Functions
  // ======================
  void _hideAlert() {
    setState(() {
      showAlert = false;
      _initializeCamera();
    });
  }

  // ======================
  //  Map Zoom Functions
  // ======================
  void _zoomIn() {
    if (mapController != null) {
      _currentZoom = (_currentZoom + 1).clamp(1.0, 19.0);
      mapController!.move(mapController!.camera.center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (mapController != null) {
      _currentZoom = (_currentZoom - 1).clamp(1.0, 19.0);
      mapController!.move(mapController!.camera.center, _currentZoom);
    }
  }

  // ======================
  //  Build Method
  // ======================
  @override
  Widget build(BuildContext context) {
    // 1. Extract battery data at the top of build:
    final mavlinkController = Provider.of<MavlinkController>(context);
    final messages = mavlinkController.messages;

    // Ambil pesan terbaru dari masing-masing tipe MAVLink
    final sysStatusMsg = messages.lastWhere(
      (msg) => msg.type == 'SYS_STATUS',
      orElse: () => MavlinkMessage(type: 'SYS_STATUS', data: {}),
    );
    final globalPosMsg = messages.lastWhere(
      (msg) => msg.type == 'GLOBAL_POSITION_INT',
      orElse: () => MavlinkMessage(type: 'GLOBAL_POSITION_INT', data: {}),
    );
    final vfrHudMsg = messages.lastWhere(
      (msg) => msg.type == 'VFR_HUD',
      orElse: () => MavlinkMessage(type: 'VFR_HUD', data: {}),
    );
    final attitudeMsg = messages.lastWhere(
      (msg) => msg.type == 'ATTITUDE',
      orElse: () => MavlinkMessage(type: 'ATTITUDE', data: {}),
    );
    final gpsRawMsg = messages.lastWhere(
      (msg) => msg.type == 'GPS_RAW_INT',
      orElse: () => MavlinkMessage(type: 'GPS_RAW_INT', data: {}),
    );
    final scaledPressMsg = messages.lastWhere(
      (msg) => msg.type == 'SCALED_PRESSURE',
      orElse: () => MavlinkMessage(type: 'SCALED_PRESSURE', data: {}),
    );

    // Ambil data dari pesan
    // GLOBAL_POSITION_INT lat/lon biasanya skala 1E7 (derajat * 1e7)
    double? rawLat = globalPosMsg.data['lat'] != null
        ? (globalPosMsg.data['lat'] as num).toDouble() / 1e7
        : null;
    double? rawLon = globalPosMsg.data['lon'] != null
        ? (globalPosMsg.data['lon'] as num).toDouble() / 1e7
        : null;
    double? rawAlt = globalPosMsg.data['alt'] != null
        ? (globalPosMsg.data['alt'] as num).toDouble()
        : null; // mm / cm tergantung frame, asumsi mm -> /1000 di display
    double? rawHdg = globalPosMsg.data['hdg'] != null
        ? (globalPosMsg.data['hdg'] as num).toDouble()
        : null; // centi-deg? jika iya bisa /100, namun dibiarkan sesuai sebelumnya
    double? rawAirspeed = vfrHudMsg.data['airspeed'] != null
        ? (vfrHudMsg.data['airspeed'] as num).toDouble()
        : null;
    double? rawGroundSpeed = vfrHudMsg.data['groundspeed'] != null
        ? (vfrHudMsg.data['groundspeed'] as num).toDouble()
        : null;
    double? rawCompass = vfrHudMsg.data['heading'] != null
        ? (vfrHudMsg.data['heading'] as num).toDouble()
        : null;
    double? rawPitch = attitudeMsg.data['pitch'] != null
        ? (attitudeMsg.data['pitch'] as num).toDouble()
        : null;
    double? rawRoll = attitudeMsg.data['roll'] != null
        ? (attitudeMsg.data['roll'] as num).toDouble()
        : null;
    double? rawYaw = attitudeMsg.data['yaw'] != null
        ? (attitudeMsg.data['yaw'] as num).toDouble()
        : null;
    double? rawBarometers = scaledPressMsg.data['press_diff'] != null
        ? (scaledPressMsg.data['press_diff'] as num).toDouble()
        : null;

    // Normalisasi aman
    final lat = safeNum<double>(rawLat, _center.latitude);
    final lon = safeNum<double>(rawLon, _center.longitude);
    final altMeters = safeNum<double>(rawAlt, 0.0) / 10000.0; // asumsi mm
    final hdg = safeNum<double>(rawHdg, 0.0);
    final airspeed = safeNum<double>(rawAirspeed, 0.0);
    final groundspeed = safeNum<double>(rawGroundSpeed, 0.0);
    final compass = safeNum<double>(rawCompass, 0.0) % 360.0;
    final pitchDeg = safeNum<double>(rawPitch, 0.0) * 57.29577951308232;
    final rollDeg = safeNum<double>(rawRoll, 0.0) * 57.29577951308232;
    final yawDeg = safeNum<double>(rawYaw, 0.0) * 57.29577951308232;
    final barometers = safeNum<double>(rawBarometers, 0.0);
    // GPS RAW INT (HDOP & satellites)
    int? satellitesVisible = gpsRawMsg.data['satellites_visible'];
    double? eph = gpsRawMsg.data['eph'] != null
        ? (gpsRawMsg.data['eph'] as num).toDouble()
        : null; // HDOP scaled *100
    double? hdop = eph != null ? eph / 100.0 : null;
    int? batteryRemaining = sysStatusMsg.data['battery_remaining'];
    // print(batteryRemaining);
    int? dropRate = sysStatusMsg.data['drop_rate_comm'];
    // Konversi drop rate (0 = bagus) menjadi kualitas link (100 = bagus)
    int? linkQuality = dropRate != null ? (100 - dropRate).clamp(0, 100) : null;
    // print('raw dropRate=$dropRate linkQuality=$linkQuality');
    // For data in the navbar
    // Auto-center jika koordinat berubah signifikan
    if (mapController != null) {
      if ((_lastLat != lat || _lastLon != lon) &&
          lat.isFinite &&
          lon.isFinite) {
        _lastLat = lat;
        _lastLon = lon;
        // Hindari spam: hanya center jika zoom cukup besar atau pertama kali
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            mapController!.move(LatLng(lat, lon), _currentZoom);
          }
        });
        // Tambah ke jejak lintasan (track) dengan threshold jarak agar tidak terlalu rapat
        final currentPoint = LatLng(lat, lon);
        if (_track.isEmpty) {
          _track.add(currentPoint);
        } else {
          final last = _track.last;
          // Jarak minimal 2 meter sebelum menambah titik baru
          try {
            final d = _distance(currentPoint, last);
            if (d > 2) _track.add(currentPoint);
          } catch (_) {
            // fallback jika perhitungan gagal (jarang terjadi)
            _track.add(currentPoint);
          }
          // Batasi panjang list (misal 5000 titik) untuk memori
          if (_track.length > 5000) {
            _track.removeRange(0, _track.length - 5000);
          }
        }
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              onMapReady: () {
                // Pastikan marker center pada awalnya
                if (mapController != null) {
                  mapController!.move(_center, _currentZoom);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.falcon_gcs',
              ),
              if (_track.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _track,
                      strokeWidth: 3,
                      color: Colors.redAccent.withOpacity(0.8),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(
                      lat.isFinite ? lat : _center.latitude,
                      lon.isFinite ? lon : _center.longitude,
                    ),
                    child: Image.network(
                      'https://cdn-icons-png.flaticon.com/512/684/684908.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Navbar(
              onConnect: connectToBackend,
              ipAddress: ipAddress,
              flightmodeValue:
                  context.watch<MavlinkController>().currentMode.isNotEmpty
                      ? context.watch<MavlinkController>().currentMode
                      : flightmodeValue,
              flightmode: flightmode,
              onFlightmodeChanged: (String? value) {
                if (value == null) return;
                // Update local fallback
                setState(() {
                  flightmodeValue = value;
                });
                // Send to backend
                socketService.setMode(value);
              },
              isArming: context.watch<MavlinkController>().armed,
              onToggleArming: _toggleArming,
              batteryRemaining: batteryRemaining,
              connected: isConnected,
              dropRate: linkQuality,
              onDataPressed: toggleInfoPanel,
            ),
          ),
          if (showInfoPanel)
            Positioned(
              top: 80,
              left: 40,
              child: Column(
                children: [
                  Container(
                    width: 350,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text("Longitude",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text("Latitude",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text(lon.toString(),
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(lat.toString(),
                                    style: TextStyle(color: Colors.white))),
                          ],
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  Container(
                    width: 350,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text("Altitude(m)",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text("Heading(°)",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text(
                                    altMeters != 0.0
                                        ? "${altMeters.toStringAsFixed(2)} m"
                                        : "0.00",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    hdg != 0.0
                                        ? "${hdg.toStringAsFixed(1)}°"
                                        : "0.0",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        SizedBox(height: 17),
                        Row(
                          children: [
                            Expanded(
                                child: Text("Air Speed(m/s)",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text("Ground Speed(m/s)",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text(
                                    "${airspeed.toStringAsFixed(2)} m/s",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    "${groundspeed.toStringAsFixed(2)} m/s",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        SizedBox(height: 17),
                        Row(
                          children: [
                            Expanded(
                                child: Text("Pitch(°)",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text("Roll(°)",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text("${pitchDeg.toStringAsFixed(2)}°",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text("${rollDeg.toStringAsFixed(2)}°",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        SizedBox(height: 17),
                        Row(
                          children: [
                            Expanded(
                                child: Text("Yaw(°)",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text("Barometers(hPa)",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text("${yawDeg.toStringAsFixed(2)}°",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    "${barometers.toStringAsFixed(2)} hPa",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _compas(compass),
                SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    _speedometer(airspeed),
                    SizedBox(width: 20),
                    _altitudeMeter(altMeters, rollDeg, pitchDeg),
                    SizedBox(width: 20),
                  ],
                ),
              ],
            ),
          ),
          if (showAlert)
            Alert(
              color: alertColor,
              title: alertTitle,
              description: alertDescription,
              onApply: _hideAlert,
            ),
          Positioned(
            left: 37,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                    child: Container(
                  width: 190,
                  height: 190,
                  padding: EdgeInsets.all(5),
                  color: Colors.white,
                  child: ClipOval(
                    child: Container(
                      width: 180,
                      height: 180,
                      color: Colors.white,
                      child: _initializeControllerFuture == null
                          ? Center(
                              child: CircularProgressIndicator(),
                            )
                          : FutureBuilder(
                              future: _initializeControllerFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.done) {
                                  return CameraPreview(
                                    _cameraController,
                                    child: Center(
                                      child: Text(
                                        "+",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 17),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              }),
                    ),
                  ),
                )),
                SizedBox(height: 17),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _zoomOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                      ),
                      child: Icon(Icons.remove, color: Colors.black),
                    ),
                    ElevatedButton(
                      onPressed: _zoomIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                      ),
                      child: Icon(Icons.add, color: Colors.black),
                    ),
                  ],
                ),
                SizedBox(height: 17),
                // Tombol clear track
                ElevatedButton(
                  onPressed: () => setState(() => _track.clear()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline, color: Colors.black, size: 16),
                      SizedBox(width: 6),
                      Text('Clear Track',
                          style: TextStyle(color: Colors.black, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(height: 9),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Text(
                        "hdop ${hdop != null ? hdop.toStringAsFixed(1) : '0.0'}",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(
                        width: 30,
                      ),
                      Text(
                        "sats ${satellitesVisible ?? 0}",
                        style: TextStyle(color: Colors.white),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          Positioned(
            bottom: 39,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 147,
                    padding: EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(50)),
                    child: Column(
                      children: [
                        Text(
                          "FLIGHT TIME",
                          style: TextStyle(color: Colors.white, fontSize: 8),
                        ),
                        Text("00:00:00",
                            style:
                                TextStyle(color: Colors.white, fontSize: 20)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedometer(double? airspeed) {
    return SizedBox(
        width: 150,
        height: 150,
        child: ClipOval(
            child: SfRadialGauge(
          enableLoadingAnimation: true,
          backgroundColor: Colors.white,
          axes: [
            RadialAxis(
              minimum: 0,
              maximum: 220,
              pointers: [
                NeedlePointer(
                  value: airspeed ?? 0.0,
                  needleColor: Colors.red,
                  needleLength: 1,
                ),
              ],
              annotations: [
                GaugeAnnotation(
                  widget: Text(
                      airspeed != null ? airspeed.toStringAsFixed(0) : "0",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  angle: 90,
                  positionFactor: 0.5,
                )
              ],
            )
          ],
        )));
  }

  Widget _compas(compass) {
    // compass value expected in degrees 0-360 (0 = North)
    final double deg = ((compass ?? 0.0) as num).toDouble() % 360.0;
    final double radians = deg * math.pi / 180.0; // correct conversion
    return ClipOval(
      child: Container(
        width: 100,
        height: 100,
        color: Colors.white,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/compass.png',
              fit: BoxFit.cover,
            ),
            Transform.rotate(
              angle: radians,
              child: Image.asset(
                'assets/images/needle.png',
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _altitudeMeter(alt, roll, pitch) {
    return Container(
        height: 150,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(255),
          color: Colors.black87,
        ),
        child: Row(
          children: [
            // Altimeter Layer
            CustomPaint(
              size: Size(200, 100),
              painter: AltimeterPainter(altitude: alt ?? 0.0),
            ),
            // Attitude Indicator Layer
            CustomPaint(
              size: Size(120, 120),
              painter: AttitudeIndicatorPainter(
                  roll: roll ?? 0.0, pitch: pitch ?? 0.0),
            ),
          ],
        ));
  }
}
