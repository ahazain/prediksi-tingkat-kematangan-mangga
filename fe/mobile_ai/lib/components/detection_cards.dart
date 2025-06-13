import 'package:flutter/material.dart';

class DetectionCards extends StatelessWidget {
  final List<dynamic> detections;

  const DetectionCards({super.key, required this.detections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(detections.length, (index) {
        final item = detections[index];
        final bbox = item['bounding_box'] ?? {};
        final width = (bbox['xmax'] ?? 0) - (bbox['xmin'] ?? 0);
        final height = (bbox['ymax'] ?? 0) - (bbox['ymin'] ?? 0);

        return Card(
          color: Colors.deepPurple.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mangga ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Grade: ${item['grade'] ?? '-'}"),
                Text("Tingkat Kematangan: ${item['ripeness_level'] ?? '-'}"),
                Text("Ukuran: ${height.abs()} × ${width.abs()}"),
              ],
            ),
          ),
        );
      }),
    );
  }
}
