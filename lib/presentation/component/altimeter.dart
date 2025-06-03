// Import Flutter packages
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AttitudeIndicatorPainter extends CustomPainter {
  final double roll;
  final double pitch;

  AttitudeIndicatorPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the blue and brown background
    Paint paint = Paint()..style = PaintingStyle.fill;

    // Sky (blue part)
    paint.color = Colors.blue;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), math.pi,
        math.pi, false, paint);

    // Ground (brown part)
    paint.color = Colors.brown;
    canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height), 0, math.pi, false, paint);

    // Horizon Line
    paint.color = Colors.white;
    paint.strokeWidth = 2;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);

    // Draw pitch lines and roll indicators
    // (Add logic for lines, text, and rotation)
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AltimeterPainter extends CustomPainter {
  final double altitude;

  AltimeterPainter({required this.altitude});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    // Draw scale lines, numbers, and current altitude
    // (Add logic for lines, text, and dynamic values)
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    for (int i = -3; i <= 3; i++) {
      double y = size.height / 2 - i * 20;
      if (i % 2 == 0) {
        canvas.drawLine(Offset(size.width / 2 - 20, y),
            Offset(size.width / 2 + 20, y), paint);
        TextPainter textPainter = TextPainter(
          text: TextSpan(
              text: '${altitude + i}',
              style: TextStyle(color: Colors.white, fontSize: 10)),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(size.width / 2 + 25, y - 7));
      } else {
        canvas.drawLine(Offset(size.width / 2 - 10, y),
            Offset(size.width / 2 + 10, y), paint);
      }
    }
    // Draw current altitude
    TextPainter currentAltitude = TextPainter(
      text: TextSpan(
          text: '$altitude m',
          style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    currentAltitude.layout();
    currentAltitude.paint(canvas, Offset(10, size.height / 2 - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
