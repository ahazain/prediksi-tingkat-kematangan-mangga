import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImagePreviewBox extends StatelessWidget {
  final File? imageFile;
  final Uint8List? imageBytes;

  const ImagePreviewBox({
    super.key,
    required this.imageFile,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (kIsWeb) {
      if (imageBytes != null) {
        child = Image.memory(imageBytes!, fit: BoxFit.cover);
      } else {
        child = const Icon(Icons.image, size: 80, color: Colors.grey);
      }
    } else {
      if (imageFile != null) {
        child = Image.file(imageFile!, fit: BoxFit.cover);
      } else {
        child = const Icon(Icons.image, size: 80, color: Colors.grey);
      }
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: Colors.teal[300],
          child: Center(child: child),
        ),
      ),
    );
  }
}
