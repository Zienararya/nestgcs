import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:falcon_gcs/component/alert.dart';
import 'package:falcon_gcs/component/navbar.dart';

class Homepage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Homepage({super.key, required this.cameras});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late GoogleMapController mapController;
  late CameraController _cameraController;
  Future<void>? _initializeControllerFuture;
  final LatLng _center = const LatLng(-7.276716204463224, 112.79310750593704);
  static const List<String> connection = <String>[
    'PORT',
    'AUTO',
    'COM8',
    'UDP',
    'TCP'
  ];
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
  static String connectionValue = connection.first;
  static String flightmodeValue = flightmode.first;
  static String baudrateValue = baudrate.first;
  bool? isArming;
  bool showAlert = false;
  Color alertColor = Colors.red;
  String alertTitle = "";
  String alertDescription = "";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

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

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

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

  void _hideAlert() {
    setState(() {
      showAlert = false;
      _initializeCamera();
    });
  }

  void _zoomIn() {
    mapController.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    mapController.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.hybrid,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              mapController = controller;
            },
            markers: {
              Marker(
                markerId: MarkerId("vehicle1"),
                position: _center,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
              ),
            },
            zoomControlsEnabled: false,
          ),
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
            child: Row(
              children: [
                _buildSpeedometer(),
                SizedBox(width: 20),
                _buildAltitudeMeter(),
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

  Widget _buildSpeedometer() {
    return SizedBox(
      width: 100,
      height: 100,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(minimum: 0, maximum: 100, pointers: [
            NeedlePointer(value: 40),
          ])
        ],
      ),
    );
  }

  Widget _buildAltitudeMeter() {
    return SizedBox(
      width: 100,
      height: 100,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(minimum: 0, maximum: 500, pointers: [
            NeedlePointer(value: 120),
          ])
        ],
      ),
    );
  }
}
