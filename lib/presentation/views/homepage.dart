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
  var connection = ['PORT', 'AUTO', 'COM8', 'UDP', 'TCP'];
  static const List<String> flightmode = <String>['Stabilize', 'Auto', 'RTL'];
  static const List<String> baudrate = <String>[
    'BAUDRATE',
    '600',
    '1200',
    '2400',
    '4800',
    '9600',
    '14400',
    '19200',
    '38400',
    '57600',
    '115200',
    '128000',
    '256000'
  ];
  static String connectionValue = 'PORT';
  static String flightmodeValue = flightmode.first;
  static String baudrateValue = baudrate.first;
  bool? isArming;
  bool showAlert = false;
  Color alertColor = Colors.red;
  String alertTitle = "";
  String alertDescription = "";

  // init function(function run when apps started)
  @override
  void initState() {
    super.initState();
    final controller = Provider.of<MavlinkController>(context, listen: false);
    final socketService = SocketService();
    socketService.initSocket(controller, backendIP: 'localhost');
    _initializeCamera();
    // initPorts();
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
              connectionValue: connectionValue,
              connection: connection,
              onConnectionChanged: (String? connvalue) {
                setState(() {
                  connectionValue = connvalue!;
                });
              },
              baudrateValue: baudrateValue,
              baudrate: baudrate,
              onBaudrateChanged: (String? baudvalue) {
                setState(() {
                  baudrateValue = baudvalue!;
                });
              },
              flightmodeValue: flightmodeValue,
              flightmode: flightmode,
              onFlightmodeChanged: (String? value) {
                setState(() {
                  flightmodeValue = value!;
                });
              },
              isArming: isArming ?? false,
              onToggleArming: _toggleArming,
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
