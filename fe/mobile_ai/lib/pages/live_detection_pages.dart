import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import '../components/box_overlay_painter.dart'; // 

class LiveDetectionPage extends StatefulWidget {
  const LiveDetectionPage({super.key});

  @override
  State<LiveDetectionPage> createState() => _LiveDetectionPageState();
}

class _LiveDetectionPageState extends State<LiveDetectionPage> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  Map<String, dynamic>? _detectionResult;
  ui.Image? _lastImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose(); // 
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // Resolusi bisa disesuaikan untuk performa
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    _cameraController!.startImageStream((CameraImage image) {
      if (_isProcessing) return; // 

      setState(() {
        _isProcessing = true;
      });
      _processCameraImage(image);
    });
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      // Konversi YUV ke JPEG, sama seperti di kode Anda 
      final jpegBytes = await _convertYUV420toJPEG(image);
      if (jpegBytes == null) return;

      // Buat ui.Image untuk painter dari bytes yang sama
      final ui.Image imageForPainter = await decodeImageFromList(jpegBytes);

      // Kirim request ke backend 
      var request = http.MultipartRequest('POST', Uri.parse('https://api.newshub.store/predict'));
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'live_frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final response = await request.send();

      if (response.statusCode == 200) { // 
        final respStr = await response.stream.bytesToString();
        final parsedJson = jsonDecode(respStr);
        if (mounted) {
          setState(() {
            _detectionResult = parsedJson;
            _lastImage = imageForPainter; // Simpan gambar yang sesuai dengan hasil deteksi
          });
        }
      } else {
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending frame: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Pindahkan fungsi konversi YUV ke JPEG dari kode Anda
  Future<Uint8List?> _convertYUV420toJPEG(CameraImage image) async {
    // Implementasi lengkap dari `_convertYUV420toJPEG` atau `convertYUV420toImage`
    // dari kode Anda bisa disalin ke sini.
    try {
        final width = image.width;
        final height = image.height;
        final img.Image rgbImage = img.Image(width: width, height: height);
        // ... (logika konversi pixel dari YUV ke RGB) ...
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                final int uvIndex = (image.planes[1].bytesPerPixel! * (x / 2).floor() + image.planes[1].bytesPerRow * (y / 2).floor());
                final int index = y * image.planes[0].bytesPerRow + x;
                final yp = image.planes[0].bytes[index];
                final up = image.planes[1].bytes[uvIndex];
                final vp = image.planes[2].bytes[uvIndex];
                final r = (yp + 1.370705 * (vp - 128)).clamp(0, 255).toInt();
                final g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).clamp(0, 255).toInt();
                final b = (yp + 1.732446 * (up - 128)).clamp(0, 255).toInt();
                rgbImage.setPixelRgb(x, y, r, g, b);
            }
        }
        return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 85));
    } catch (e) {
        debugPrint("Conversion error: $e");
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController?.value.isInitialized != true) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Deteksi Langsung")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Tampilan Kamera
          CameraPreview(_cameraController!),

          // Layer 2: Bounding Box (jika ada deteksi)
          if (_detectionResult != null && _lastImage != null)
            CustomPaint(
              painter: BoxOverlayPainter(
                _lastImage!,
                _detectionResult!['detections'] ?? [],
              ),
            ),
        ],
      ),
    );
  }
}