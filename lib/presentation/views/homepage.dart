import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import 'package:falcon_gcs/data/services/socket_service.dart';
// import '../widget/attitude_indicator.dart';
// import '../widget/altimeter.dart';
// import '../widget/speedometer.dart';
// import '../widget/compas.dart';

class Homepage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const Homepage({Key? key, required this.cameras}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late CameraController _cameraController;
  late SocketService socketService;
  GoogleMapController? mapController;

  // State variables
  String connectionValue = 'PORT';
  String baudrateValue = '57600';
  String flightmodeValue = 'STABILIZE';
  bool isArming = false;
  double heading = 0.0;
  double speed = 0.0;
  double altitude = 0.0;
  String flightTime = "00:00:00";

  late StreamSubscription<CompassEvent> _compassSubscription;
  late Timer flightTimer;
  final Stopwatch _stopwatch = Stopwatch();

  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(-6.914744, 107.609810), // Koordinat default
    zoom: 16,
  );

  @override
  void initState() {
    super.initState();
    socketService = context.read<SocketService>();
    _initializeCamera();
    _startCompassListener();
  }

  void _initializeCamera() {
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
    );

    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _startCompassListener() {
    _compassSubscription = FlutterCompass.events!.listen((event) {
      setState(() {
        heading = event.heading ?? 0.0;
      });
    });
  }

  void _startFlightTimer() {
    _stopwatch.start();
    flightTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final d = _stopwatch.elapsed;
      setState(() {
        flightTime =
            "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  void _stopFlightTimer() {
    _stopwatch.stop();
    _stopwatch.reset();
    flightTimer.cancel();
    setState(() => flightTime = "00:00:00");
  }

  void _toggleArming() {
    setState(() {
      isArming = !isArming;
      if (isArming) {
        _startFlightTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flight started')),
        );
      } else {
        _stopFlightTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flight stopped')),
        );
      }
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _compassSubscription.cancel();
    socketService.dispose();
    if (_stopwatch.isRunning) {
      flightTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocketService>(
      builder: (context, value, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Google Maps
              Positioned.fill(
                child: GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: _initialCameraPosition,
                  mapType: MapType.hybrid,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
              ),
              // Kamera
              if (_cameraController.value.isInitialized)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: CameraPreview(_cameraController),
                  ),
                ),
              // Attitude Indicator
              // const Positioned(
              //   top: 40,
              //   right: 20,
              //   child: SizedBox(
              //       width: 120, height: 120, child: AttitudeIndicator()),
              // ),
              // Compass
              // Positioned(
              //   top: 40,
              //   left: 20,
              //   child: SizedBox(
              //       width: 100, height: 100, child: Compas(heading: heading)),
              // ),
              // Altimeter
              // Positioned(
              //   top: 180,
              //   right: 20,
              //   child: Altimeter(altitude: altitude),
              // ),
              // Speedometer
              // Positioned(
              //   top: 180,
              //   left: 20,
              //   child: Speedometer(speed: speed),
              // ),
              // Bottom Controls
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Text(
                      flightTime,
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DropdownButton<String>(
                          value: connectionValue,
                          items: ['PORT', 'USB', 'TCP', 'UDP']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => connectionValue = val!),
                        ),
                        DropdownButton<String>(
                          value: baudrateValue,
                          items: ['9600', '57600', '115200']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => baudrateValue = val!),
                        ),
                        DropdownButton<String>(
                          value: flightmodeValue,
                          items: ['STABILIZE', 'AUTO', 'GUIDED']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => flightmodeValue = val!),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isArming ? Colors.red : Colors.green,
                          ),
                          onPressed: _toggleArming,
                          child: Text(isArming ? 'DISARM' : 'ARM'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
