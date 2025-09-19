// Import Flutter packages
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AttitudeIndicatorPainter extends CustomPainter {
  final double roll; // degrees
  final double pitch; // degrees (nose up +)

  AttitudeIndicatorPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final double radius = math.min(w, h) / 2 - 1;

    // Konversi derajat ke radian
    final double rollRad = roll * math.pi / 180.0;
    // Skala pitch dinamis: semakin kecil radius semakin rapat.
    // radius ~60 (ukuran 120x120) -> pitchScale ~1.8 px/deg
    final double pitchScale = radius / 33.0; // atur denom untuk sensitivitas
    final double pitchOffset =
        pitch * pitchScale; // positif pitch → horizon turun

    final skyPaint = Paint()..color = Colors.blue.shade600;
    final groundPaint = Paint()..color = const Color(0xFF805533);
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.save();
    // Clip agar gambar tidak keluar lingkaran
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Pindahkan ke tengah lalu rotasi & translate pitch di dalam clip
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rollRad);
    canvas.translate(0, pitchOffset);

    // Gunakan ukuran moderat (tidak perlu super besar karena sudah di-clip)
    final double span = h * 1.6; // cukup untuk rotasi & pitch kecil
    final Rect skyRect = Rect.fromCenter(
        center: Offset(0, -span / 2), width: w * 1.6, height: span);
    final Rect groundRect = Rect.fromCenter(
        center: Offset(0, span / 2), width: w * 1.6, height: span);
    canvas.drawRect(skyRect, skyPaint);
    canvas.drawRect(groundRect, groundPaint);

    // Garis horizon (gunakan 0.5 untuk pixel alignment agar tampak tajam dan tepat di tengah)
    canvas.drawLine(Offset(-w * 2, 0.5), Offset(w * 2, 0.5), linePaint);

    // Pitch marks
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    // Batasi range pitch yang digambar agar tidak terlalu padat di ruang kecil
    for (int deg = -30; deg <= 30; deg += 5) {
      if (deg == 0) continue;
      final double y = -deg * pitchScale;
      if (y.abs() > radius)
        continue; // jangan gambar di luar clip untuk efisiensi
      final bool major = deg % 10 == 0;
      // Panjang garis proporsional terhadap radius (lebih kecil dari sebelumnya)
      final double half = major ? radius * 0.55 : radius * 0.38;
      canvas.drawLine(Offset(-half, y), Offset(half, y), linePaint);
      if (major) {
        final label = deg > 0 ? '+$deg' : '$deg';
        textPainter.text = TextSpan(
            text: label,
            style: const TextStyle(color: Colors.white, fontSize: 10));
        textPainter.layout();
        if (y > -radius + 10 && y < radius - 10) {
          textPainter.paint(canvas, Offset(half + 3, y - 6));
          textPainter.paint(
              canvas, Offset(-half - 3 - textPainter.width, y - 6));
        }
      }
    }
    canvas.restore();

    // Frame luar (tetap, tidak ikut transform)
    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, framePaint);

    // Indikator bank (roll ticks) di bagian atas frame
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    const bankTicks = [-45, -30, -20, -10, 10, 20, 30, 45];
    for (final t in bankTicks) {
      final double rad = t * math.pi / 180.0;
      final double rOuter =
          radius; // pakai radius yang sama dengan frame agar ujung tick presisi
      final double rInner = rOuter - (t % 30 == 0 ? 10 : 6);
      final Offset p1 =
          center + Offset(math.sin(rad) * rInner, -math.cos(rad) * rInner);
      final Offset p2 =
          center + Offset(math.sin(rad) * rOuter, -math.cos(rad) * rOuter);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Fixed reference airplane symbol (small wings + vertical line)
    final refPaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final double wing = w * 0.25;
    canvas.drawLine(Offset(center.dx - wing, center.dy),
        Offset(center.dx + wing, center.dy), refPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 12),
        Offset(center.dx, center.dy + 12), refPaint);
  }

  @override
  bool shouldRepaint(covariant AttitudeIndicatorPainter old) {
    return (old.roll - roll).abs() > 0.1 || (old.pitch - pitch).abs() > 0.1;
  }
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
        final tickValue = (altitude + i).toStringAsFixed(2);
        TextPainter textPainter = TextPainter(
          text: TextSpan(
              text: tickValue,
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
    final currentAlt = altitude.toStringAsFixed(2);
    TextPainter currentAltitude = TextPainter(
      text: TextSpan(
          text: '$currentAlt m',
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
