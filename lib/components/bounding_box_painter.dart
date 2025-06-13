import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class BoundingBoxPainter extends CustomPainter {
  final Uint8List imageBytes;
  final List<dynamic> detections;
  ui.Image? _image;

  BoundingBoxPainter(this.imageBytes, this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    if (_image == null) return;

    double scaleX = size.width / _image!.width;
    double scaleY = size.height / _image!.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color.fromARGB(255, 255, 0, 0);

    canvas.drawImageRect(
      _image!,
      Rect.fromLTWH(0, 0, _image!.width.toDouble(), _image!.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    for (var item in detections) {
      final bbox = item['bounding_box'];
      final rect = Rect.fromLTRB(
        bbox['xmin'] * scaleX,
        bbox['ymin'] * scaleY,
        bbox['xmax'] * scaleX,
        bbox['ymax'] * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  Future<void> loadImage() async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    _image = frame.image;
  }
}
