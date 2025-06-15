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
    'sangat mentah': Color(0xFF7E57C2), // ungu muda
    'mentah': Color(0xFF42A5F5),        // biru muda
    'mengkal': Color(0xFF66BB6A),       // hijau muda
    'matang': Color(0xFFFFCA28),        // kuning emas
    'sangat matang': Color(0xFFEF5350), // merah lembut
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
                cardColor.withOpacity(0.9),
                cardColor.withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 8),
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
                  color: Colors.white,
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
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Satoshi',
      ),
    );
  }
}
