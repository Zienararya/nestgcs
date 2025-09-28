import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Navbar extends StatelessWidget {
  final String flightmodeValue;
  final List<String> flightmode;
  final ValueChanged<String?> onFlightmodeChanged;
  final bool isArming;
  final VoidCallback onToggleArming;
  final VoidCallback onDataPressed;
  final int? batteryRemaining;
  final int? dropRate;
  final bool connected;
  final VoidCallback onConnect;
  final List<String> serialDevices; // list of device names/ids
  final String? selectedDevice;
  final ValueChanged<String?> onDeviceChanged;
  final VoidCallback onRefreshDevices;
  final VoidCallback? onCalibrateLevel;

  const Navbar({
    super.key,
    required this.flightmodeValue,
    required this.flightmode,
    required this.onFlightmodeChanged,
    required this.onConnect,
    required this.isArming,
    required this.onToggleArming,
    required this.batteryRemaining,
    required this.dropRate,
    required this.connected,
    required this.onDataPressed,
    required this.serialDevices,
    required this.selectedDevice,
    required this.onDeviceChanged,
    required this.onRefreshDevices,
    this.onCalibrateLevel,
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
              Text("EFRISA",
                  style: GoogleFonts.fugazOne(
                      textStyle: TextStyle(color: Colors.white, fontSize: 20))),
              SizedBox(width: 29),
              ElevatedButton.icon(
                onPressed: onDataPressed,
                icon: Icon(Icons.assignment_add, color: Colors.black),
                label: Text("Data", style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 7),
              if (onCalibrateLevel != null)
                ElevatedButton.icon(
                  onPressed: onCalibrateLevel,
                  icon: Icon(Icons.screen_rotation_alt, color: Colors.black),
                  label: Text("Calibrate Level",
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                ),
              SizedBox(width: 7),
              // ElevatedButton.icon(
              //   onPressed: () {},
              //   icon: Icon(Icons.add_location_alt_rounded, color: Colors.black),
              //   label: Text("Plan", style: TextStyle(color: Colors.black)),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.white,
              //   ),
              // ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.wifi, color: Colors.black),
                label: Text(
                    dropRate != null && dropRate != -1 ? "$dropRate%" : "N/A",
                    style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 7),
              ElevatedButton.icon(
                  onPressed: () {},
                  icon:
                      Icon(Icons.battery_unknown_rounded, color: Colors.black),
                  label: Text(
                      batteryRemaining != null && batteryRemaining != -1
                          ? "$batteryRemaining%"
                          : "N/A",
                      style: TextStyle(color: Colors.black)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: flightmodeValue,
                    items: flightmode
                        .map((m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(color: Colors.black)),
                            ))
                        .toList(),
                    onChanged: onFlightmodeChanged,
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDevice,
                        hint: const Text('Select Device',
                            style: TextStyle(color: Colors.black54)),
                        items: serialDevices.map((d) {
                          final display =
                              d.length > 20 ? d.substring(0, 18) + '...' : d;
                          return DropdownMenuItem<String>(
                            value: d,
                            child: Text(display,
                                style: const TextStyle(color: Colors.black)),
                          );
                        }).toList(),
                        onChanged: onDeviceChanged,
                        dropdownColor: Colors.white,
                        iconEnabledColor: Colors.black,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh, color: Colors.black87),
                      onPressed: onRefreshDevices,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: Icon(
                      connected ? Icons.usb_off_rounded : Icons.usb_rounded,
                      color: Colors.black),
                  label: Text(connected ? "DISCONNECT" : "CONNECT",
                      style: const TextStyle(color: Colors.black)),
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.white))),
              const SizedBox(width: 28),
            ],
          ),
        ],
      ),
    );
  }
}
