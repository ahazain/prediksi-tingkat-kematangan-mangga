import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class BoxOverlayPainter extends CustomPainter {
  final ui.Image image;
  final List<dynamic> detections;

  BoxOverlayPainter(this.image, this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.red;

    canvas.drawImage(image, Offset.zero, Paint());

    for (var item in detections) {
      final bbox = item['bounding_box'];
      final rect = Rect.fromLTRB(
        bbox['xmin'].toDouble(),
        bbox['ymin'].toDouble(),
        bbox['xmax'].toDouble(),
        bbox['ymax'].toDouble(),
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
