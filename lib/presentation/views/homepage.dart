import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:falcon_gcs/data/controllers/mavlink_controller.dart';
import 'package:falcon_gcs/data/services/socket_service.dart';
import 'package:arcgis_map_sdk/arcgis_map_sdk.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:falcon_gcs/presentation/component/alert.dart';
import 'package:falcon_gcs/presentation/component/navbar.dart';
import 'package:falcon_gcs/presentation/component/altimeter.dart';
import 'package:falcon_gcs/data/models/mavlink_message.dart';

class Homepage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Homepage({super.key, required this.cameras});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  double speed = 50.0; // Simulasi speedometer (km/h)
  double altitude = 5.0; // Simulasi altimeter (meter)
  double heading = 0.0; // Heading dari kompas
  ArcgisMapController? mapController;
  late CameraController _cameraController;
  Future<void>? _initializeControllerFuture;
  final LatLng _center = const LatLng(-7.276716204463224, 112.79310750593704);
  LatLng planePosition = const LatLng(-7.276716204463224, 112.79310750593704);
  String planePinLayerId = 'plane_pin';
  static const List<String> flightmode = <String>['Stabilize', 'Auto', 'RTL'];
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

  // init function(function run when apps started)
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    socketService = SocketService();
    // Update kompas secara real-time
    FlutterCompass.events!.listen((event) {
      setState(() {
        heading = event.heading ?? 0.0;
      });
    });
  }

// Camera Function
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

  void toggleInfoPanel() {
    setState(() {
      showInfoPanel = !showInfoPanel;
      _initializeCamera();
    });
  }

  void connectToBackend() {
    final controller = Provider.of<MavlinkController>(context, listen: false);
    final ip = ipAddress.text.trim();

    if (isConnected) {
      SocketService socketService = SocketService();
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
    SocketService socketService = SocketService();
    socketService.initSocket(controller, backendIP: ip, onError: (error) {
      setState(() {
        alertColor = Colors.red;
        alertTitle = "Connection Failed";
        alertDescription = error;
        showAlert = true;
        isConnected = false;
      });
    });
    setState(() {
      alertColor = Colors.green;
      alertTitle = "Connecting";
      alertDescription = "Connecting to backend at $ip";
      showAlert = true;
      isConnected = true;
    });
  }

// turn off camera
  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

// Arming/disarm button function
  void _toggleArming() {
    setState(() {
      isArming = !(isArming ?? false);
      if (isArming == true) {
        alertColor = Colors.red;
        alertTitle = "Armed";
        alertDescription = "warning, the plane is arming";
      } else {
        alertColor = Colors.green;
        alertTitle = "Disarmed";
        alertDescription = "the plane is disarming";
      }
      _initializeCamera();
      showAlert = true;
    });
  }

// Hide alert function
  void _hideAlert() {
    setState(() {
      showAlert = false;
      _initializeCamera();
    });
  }

// Zoom in button maps function
  void _zoomIn() {
    mapController?.zoomIn(lodFactor: 5);
  }

// Zoom out button maps function
  void _zoomOut() {
    mapController?.zoomOut(lodFactor: 5);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Extract battery data at the top of build:
    final mavlinkController = Provider.of<MavlinkController>(context);
    final messages = mavlinkController.messages;

    final sysStatusMsg = messages.firstWhere(
      (msg) => msg.type == 'SYS_STATUS',
      orElse: () => MavlinkMessage(type: 'SYS_STATUS', data: {}),
    );

    // Extract latest MAVLink messages for info panel
    final globalPosMsg = messages.firstWhere(
      (msg) => msg.type == 'GLOBAL_POSITION_INT',
      orElse: () => MavlinkMessage(type: 'GLOBAL_POSITION_INT', data: {}),
    );
    final vfrHudMsg = messages.firstWhere(
      (msg) => msg.type == 'VFR_HUD',
      orElse: () => MavlinkMessage(type: 'VFR_HUD', data: {}),
    );
    final attitudeMsg = messages.firstWhere(
      (msg) => msg.type == 'ATTITUDE',
      orElse: () => MavlinkMessage(type: 'ATTITUDE', data: {}),
    );
    final sysStatusMsg2 = messages.firstWhere(
      (msg) => msg.type == 'SYS_STATUS',
      orElse: () => MavlinkMessage(type: 'SYS_STATUS', data: {}),
    );
    double? lat = globalPosMsg.data['lat'] != null
        ? (globalPosMsg.data['lat'] as num).toDouble()
        : null;
    double? lon = globalPosMsg.data['lon'] != null
        ? (globalPosMsg.data['lon'] as num).toDouble()
        : null;
    double? alt = globalPosMsg.data['alt'] != null
        ? (globalPosMsg.data['alt'] as num).toDouble()
        : null;
    double? hdg = globalPosMsg.data['hdg'] != null
        ? (globalPosMsg.data['hdg'] as num).toDouble()
        : null;
    double? airspeed = vfrHudMsg.data['airspeed'] != null
        ? (vfrHudMsg.data['airspeed'] as num).toDouble()
        : null;
    double? groundspeed = vfrHudMsg.data['groundspeed'] != null
        ? (vfrHudMsg.data['groundspeed'] as num).toDouble()
        : null;
    double? pitch = attitudeMsg.data['pitch'] != null
        ? (attitudeMsg.data['pitch'] as num).toDouble()
        : null;
    double? roll = attitudeMsg.data['roll'] != null
        ? (attitudeMsg.data['roll'] as num).toDouble()
        : null;
    double? yaw = attitudeMsg.data['yaw'] != null
        ? (attitudeMsg.data['yaw'] as num).toDouble()
        : null;
    double? barometers = sysStatusMsg2.data['barometers'] != null
        ? (sysStatusMsg2.data['barometers'] as num).toDouble()
        : null;

    // For data in the navbar
    int? batteryRemaining;
    int? dropRate;
    if (sysStatusMsg.data.isNotEmpty) {
      batteryRemaining = sysStatusMsg.data['battery_remaining'];
      dropRate = sysStatusMsg.data['drop_rate_comm'];
    }
    return Scaffold(
      body: Stack(
        children: [
          ArcgisMap(
              apiKey:
                  'AAPTxy8BH1VEsoebNVZXo8HurFv3YbHc2f0yfy3ERSqB087Dfchm7K26G4MpDjCSnjZcmrFeGnRFUv9TgeAfcI9YgdGIQW3Y6qgbwkXxGLG1njOTJ1X1j_JK4-U9387keeSPHhgi5875mk7BT9UVNYKZyZ5acTVanrTt9-PJ4rOELliIPYsS3NLt0JOkipD8iOrYhQkND_dY3i7XReUqDx0PETUzey9z4JpqVCfgUkZ4w3o.AT1_bvMnsjjI', // <-- Replace with your ArcGIS API key
              initialCenter: _center,
              zoom: 15,
              basemap: BaseMap.arcgisNavigationNight,
              mapStyle: MapStyle.twoD,
              onMapCreated: (controller) async {
                mapController ??= controller;
                // Create the graphics layer for the plane pin
                await controller.addGraphicsLayer(
                    layerId: planePinLayerId,
                    options: GraphicsLayerOptions(fields: []));
                // Add plane pin layer and pin
                await controller.addGraphic(
                  layerId: planePinLayerId,
                  graphic: PointGraphic(
                    latitude: planePosition.latitude,
                    longitude: planePosition.longitude,
                    attributes: Attributes({'id': 'plane'}),
                    symbol: const PictureMarkerSymbol(
                      webUri:
                          "https://cdn-icons-png.flaticon.com/512/684/684908.png", // Use any plane icon you like
                      mobileUri:
                          "https://cdn-icons-png.flaticon.com/512/684/684908.png",
                      width: 40,
                      height: 40,
                    ),
                  ),
                );
              }),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Navbar(
              onConnect: connectToBackend,
              ipAddress: ipAddress,
              flightmodeValue: flightmodeValue,
              flightmode: flightmode,
              onFlightmodeChanged: (String? value) {
                setState(() {
                  flightmodeValue = value!;
                });
              },
              isArming: isArming ?? false,
              onToggleArming: _toggleArming,
              batteryRemaining: batteryRemaining,
              connected: isConnected,
              dropRate: dropRate,
              onDataPressed: toggleInfoPanel,
            ),
          ),
          if (showInfoPanel)
            Positioned(
              top: 70,
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
                                child: Text(
                                    lon != null
                                        ? lon.toStringAsFixed(4)
                                        : "0.0000",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    lat != null
                                        ? lat.toStringAsFixed(4)
                                        : "0.0000",
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
                                    alt != null
                                        ? alt.toStringAsFixed(4)
                                        : "0.0000",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    hdg != null
                                        ? hdg.toStringAsFixed(1)
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
                                    airspeed != null
                                        ? airspeed.toStringAsFixed(4)
                                        : "0.0000",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    groundspeed != null
                                        ? groundspeed.toStringAsFixed(4)
                                        : "0.0000",
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
                                child: Text(
                                    pitch != null
                                        ? pitch.toStringAsFixed(1)
                                        : "0.0",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    roll != null
                                        ? roll.toStringAsFixed(1)
                                        : "0.0",
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
                                child: Text(
                                    yaw != null
                                        ? yaw.toStringAsFixed(1)
                                        : "0.0",
                                    style: TextStyle(color: Colors.white))),
                            Expanded(
                                child: Text(
                                    barometers != null
                                        ? barometers.toStringAsFixed(4)
                                        : "0.0000",
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
                _compas(),
                SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    _speedometer(),
                    SizedBox(width: 20),
                    _altitudeMeter(),
                    SizedBox(width: 20),
                  ],
                ),
              ],
            ),
          ),
          if (showAlert)
            Positioned(
              top: 80,
              right: 20,
              child: Alert(
                color: alertColor,
                title: alertTitle,
                description: alertDescription,
                onApply: _hideAlert,
              ),
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Text(
                        "hdop 0.0",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(
                        width: 30,
                      ),
                      Text(
                        "sats 0",
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

  Widget _speedometer() {
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
                  value: 60,
                  needleColor: Colors.red,
                  needleLength: 1,
                ),
              ],
              annotations: [
                GaugeAnnotation(
                  widget: Text(
                    '60',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  angle: 90,
                  positionFactor: 0.5,
                )
              ],
            )
          ],
        )));
  }

  Widget _compas() {
    return ClipOval(
      child: Container(
        width: 100,
        height: 100,
        color: Colors.white,
        child: SizedBox(
            child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/compass.png',
              fit: BoxFit.cover,
            ),
            Transform.rotate(
              angle: (heading) * (3.141592653589793 / 180),
              child: Image.asset(
                'assets/images/needle.png',
                fit: BoxFit.cover,
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _altitudeMeter() {
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
              size: Size(150, 100),
              painter: AltimeterPainter(altitude: 5),
            ),
            SizedBox(
              width: 3,
            ),
            // Attitude Indicator Layer
            CustomPaint(
              size: Size(120, 120),
              painter: AttitudeIndicatorPainter(roll: 15, pitch: 5),
            ),
          ],
        ));
  }
}
