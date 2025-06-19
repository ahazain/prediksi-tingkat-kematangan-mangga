import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class BoxOverlayPainter extends CustomPainter {
  final ui.Image image;
  final List<dynamic> detections;

  BoxOverlayPainter(this.image, this.detections);

  final Map<String, Color> ripenessColors = {
    'sangat mentah': Colors.deepPurple,
    'mentah': Colors.blueAccent,
    'mengkal': Colors.greenAccent,
    'matang': Colors.amberAccent,
    'sangat matang': Colors.redAccent,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;

    final imageRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, srcRect, imageRect, Paint());

    for (int i = 0; i < detections.length; i++) {
      final item = detections[i];
      final bbox = item['bounding_box'];

      final left = bbox['xmin'].toDouble() * scaleX;
      final top = bbox['ymin'].toDouble() * scaleY;
      final right = bbox['xmax'].toDouble() * scaleX;
      final bottom = bbox['ymax'].toDouble() * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      final label = (item['ripeness_level'] ?? 'tidak diketahui').toLowerCase();
      final grade = item['grade'] ?? '-';
      final color = ripenessColors[label] ?? Colors.grey;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color;

      canvas.drawRect(rect, paint);
      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Mangga ${i + 1}\n',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Satoshi',
              ),
            ),
            TextSpan(
              text: 'Grade: $grade',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.normal,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);


      final offsetY = (rect.top - textPainter.height - 2) < 0
          ? rect.top + 2
          : rect.top - textPainter.height - 2;

      textPainter.paint(canvas, Offset(rect.left, offsetY));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
