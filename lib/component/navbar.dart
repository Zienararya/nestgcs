import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Navbar extends StatelessWidget {
  final String connectionValue;
  final List<String> connection;
  final ValueChanged<String?> onConnectionChanged;
  final String flightmodeValue;
  final String baudrateValue;
  final List<String> baudrate;
  final ValueChanged<String?> onBaudrateChanged;
  final List<String> flightmode;
  final ValueChanged<String?> onFlightmodeChanged;
  final bool isArming;
  final VoidCallback onToggleArming;

  const Navbar({
    super.key,
    required this.connectionValue,
    required this.connection,
    required this.onConnectionChanged,
    required this.baudrateValue,
    required this.baudrate,
    required this.onBaudrateChanged,
    required this.flightmodeValue,
    required this.flightmode,
    required this.onFlightmodeChanged,
    required this.isArming,
    required this.onToggleArming,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // ignore: deprecated_member_use
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(width: 41),
              Text("FALCONGCS",
                  style: GoogleFonts.fugazOne(
                      textStyle: TextStyle(color: Colors.white, fontSize: 20))),
              SizedBox(width: 29),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.assignment_add, color: Colors.black),
                label: Text("Data", style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 7),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.add_location_alt_rounded, color: Colors.black),
                label: Text("Plan", style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.wifi, color: Colors.black),
                label: Text("N/A", style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 7),
              ElevatedButton.icon(
                  onPressed: () {},
                  icon:
                      Icon(Icons.battery_unknown_rounded, color: Colors.black),
                  label: Text("N/A", style: TextStyle(color: Colors.black)),
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.white))),
              SizedBox(width: 7),
              ElevatedButton(
                onPressed: onToggleArming,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isArming == true ? Colors.green : Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  isArming == true ? "Armed" : "Disarmed",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(width: 7),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  "Stabilize",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
          Row(
            children: [
              PopupMenuButton<String>(
                color: Colors.white,
                onSelected: onConnectionChanged,
                itemBuilder: (BuildContext context) {
                  return connection.map((String value) {
                    return PopupMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList();
                },
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white),
                  child: Row(
                    children: [
                      Text(
                        connectionValue,
                        style: TextStyle(color: Colors.black),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.black),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 7),
              PopupMenuButton<String>(
                color: Colors.white,
                onSelected: onBaudrateChanged,
                itemBuilder: (BuildContext context) {
                  return baudrate.map((String value) {
                    return PopupMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList();
                },
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Text(
                        baudrateValue,
                        style: TextStyle(color: Colors.black),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.black),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 7),
              ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.link_rounded, color: Colors.black),
                  label: Text("CONNECT", style: TextStyle(color: Colors.black)),
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.white))),
              SizedBox(width: 28),
            ],
          ),
        ],
      ),
    );
  }
}
