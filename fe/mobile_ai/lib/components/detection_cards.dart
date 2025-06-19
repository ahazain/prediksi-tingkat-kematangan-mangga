import 'package:flutter/material.dart';

class DetectionCards extends StatelessWidget {
  final List<dynamic> detections;
  final int originalWidth;
  final int originalHeight;
  final double displayWidth;

  const DetectionCards({
    super.key,
    required this.detections,
    required this.originalWidth,
    required this.originalHeight,
    required this.displayWidth,
  });

  final Map<String, Color> ripenessColors = const {
    'sangat matang': Color(0xFFD2691E),  // orange-cokelat
    'matang': Color(0xFF7CFC00),         // hijau terang
    'mengkal': Color(0xFFFFD700),        // kuning
    'mentah': Color(0xFFFF6B6B),         // merah soft
    'sangat mentah': Color(0xFF8B0000),  // merah gelap
  };

  @override
  Widget build(BuildContext context) {
    final scale = displayWidth / originalWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(detections.length, (index) {
        final item = detections[index];
        final bbox = item['bounding_box'] ?? {};

        final width = (bbox['xmax'] ?? 0) - (bbox['xmin'] ?? 0);
        final height = (bbox['ymax'] ?? 0) - (bbox['ymin'] ?? 0);

        final scaledWidth = width * scale;
        final scaledHeight = height * scale;

        final ripeness = (item['ripeness_level'] ?? 'tidak diketahui').toLowerCase();
        final confidence = item['confidence'] ?? 0.0;
        final grade = item['grade'] ?? '-';

        final cardColor = ripenessColors[ripeness] ?? Colors.grey;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cardColor.withOpacity(0.25),
                cardColor.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mangga ${index + 1}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Satoshi',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              _buildText("Grade: $grade"),
              _buildText("Tingkat Kematangan: ${item['ripeness_level'] ?? '-'}"),
              _buildText("Ukuran (asli): ${height} × ${width} px"),
              _buildText("Confident: ${(confidence * 100).toStringAsFixed(1)}%"),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        fontFamily: 'Satoshi',
      ),
    );
  }
}
