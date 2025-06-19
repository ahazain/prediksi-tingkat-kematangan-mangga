import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:http_parser/http_parser.dart';

class StreamDetectionPage extends StatefulWidget {
  const StreamDetectionPage({super.key});

  @override
  State<StreamDetectionPage> createState() => _StreamDetectionPageState();
}

class _StreamDetectionPageState extends State<StreamDetectionPage> {
  CameraController? _cameraController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);

    _cameraController = CameraController(
      camera,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();

    _cameraController!.startImageStream((CameraImage image) {
      if (!_isProcessing) {
        _isProcessing = true;
        _processCameraImage(image).then((_) {
          _isProcessing = false;
        });
      }
    });

    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final jpegBytes = _convertYUV420toJPEG(image);
      if (jpegBytes == null) return;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.newshub.store/predict'),
      );

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        debugPrint('Detected: $respStr');
        // TODO: parse dan tampilkan bounding box
      } else {
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending frame: $e');
    }
  }

  Uint8List? _convertYUV420toJPEG(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel!;

      final imgBuffer = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final yp = image.planes[0].bytes[y * width + x];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          final r = (yp + 1.370705 * (vp - 128)).clamp(0, 255).toInt();
          final g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).clamp(0, 255).toInt();
          final b = (yp + 1.732446 * (up - 128)).clamp(0, 255).toInt();

          imgBuffer.setPixelRgb(x, y, r, g, b);
        }
      }

      return Uint8List.fromList(img.encodeJpg(imgBuffer, quality: 70));
    } catch (e) {
      debugPrint("Conversion error: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Object Detection")),
      body: _cameraController?.value.isInitialized == true
          ? CameraPreview(_cameraController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
