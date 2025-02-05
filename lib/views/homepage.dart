import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(-7.276716204463224, 112.79310750593704);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
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
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              // ignore: deprecated_member_use
              backgroundColor: Colors.black.withOpacity(0.75),
              elevation: 0,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      DropdownButton<String>(
                        items: <String>['Vehicle 1', 'Vehicle 2', 'Vehicle 3']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (_) {},
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: Colors.black,
                        style: TextStyle(color: Colors.white),
                      ),
                      VerticalDivider(color: Colors.white),
                      Icon(Icons.settings, color: Colors.white),
                      SizedBox(width: 10),
                      Icon(Icons.add_location_alt_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Icon(Icons.flight_takeoff_outlined, color: Colors.white),
                      SizedBox(width: 10),
                      Text("FALCONGCS",
                          style: GoogleFonts.fugazOne(
                              textStyle: TextStyle(
                                  color: Colors.white, fontSize: 20))),
                      SizedBox(width: 10),
                      Icon(Icons.assignment_add, color: Colors.white),
                    ],
                  ),
                  Image.asset("assets/images/logo.png", height: 40),
                  Row(
                    children: [
                      DropdownButton<String>(
                        items: <String>['Mode 1', 'Mode 2', 'Mode 3']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (_) {},
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: Colors.black,
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      DropdownButton<String>(
                        items: <String>['Arm', 'Disarm'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (_) {},
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: Colors.black,
                        style: TextStyle(color: Colors.white),
                      ),
                      VerticalDivider(color: Colors.white),
                      Row(
                        children: [
                          Icon(Icons.satellite_alt_rounded,
                              color: Colors.white),
                          SizedBox(width: 5),
                          Text("12", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      SizedBox(width: 10),
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt, color: Colors.white),
                          SizedBox(width: 5),
                          Text("75%", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      SizedBox(width: 10),
                      Row(
                        children: [
                          Icon(Icons.battery_full, color: Colors.white),
                          SizedBox(width: 5),
                          Text("85%", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              children: [
                _buildSpeedometer(),
                SizedBox(width: 20),
                _buildAltitudeMeter(),
              ],
            ),
          ),
          Positioned(
            top: 80,
            right: 20,
            child: _buildCollisionAlert(),
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

  Widget _buildCollisionAlert() {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("COLLISION ALERT",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text("Change Route: 15° W", style: TextStyle(color: Colors.white)),
          SizedBox(height: 5),
          ElevatedButton(
            onPressed: () {},
            child: Text("Apply"),
          )
        ],
      ),
    );
  }
}
