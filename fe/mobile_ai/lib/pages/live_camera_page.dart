import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../components/box_overlay_painter.dart';
import '../config/api_config.dart';

class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  List<dynamic>? _detections;
  ui.Image? _lastImage;
  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;
  int _lastCheckTimestamp = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeCamera();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.low, // Resolusi rendah agar preview super ringan & hemat kuota
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    // Throttle deteksi ke 2 detik sekali agar HP tetap 60fps & server tidak terbebani
    _cameraController!.startImageStream((CameraImage image) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!_isProcessing && (now - _lastCheckTimestamp >= 2000)) {
        _lastCheckTimestamp = now;
        _isProcessing = true;
        _processCameraImage(image);
      }
    });

    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      // Konversi YUV ke JPEG dengan downsample cepat
      Uint8List? jpegBytes = await _convertYUV420toJPEG(image);
      if (jpegBytes == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      // Rotasi 90 derajat jika mode portrait
      if (_currentOrientation == DeviceOrientation.portraitUp) {
        final originalImage = img.decodeJpg(jpegBytes);
        if (originalImage != null) {
          final rotatedImage = img.copyRotate(originalImage, angle: 90);
          jpegBytes = Uint8List.fromList(img.encodeJpg(rotatedImage, quality: 65));
        }
      }

      final uiImg = await decodeImageFromList(jpegBytes);
      if (mounted) {
        _lastImage = uiImg;
      }

      // Kirim ke endpoint khusus /predict-live (tanpa simpan DB, cepat <300ms)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.predictLiveUrl),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'live_frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamedRes = await request.send().timeout(const Duration(seconds: 4));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (mounted && parsed is Map<String, dynamic> && parsed['detections'] != null) {
          setState(() {
            _detections = parsed['detections'];
          });
        }
      }
    } catch (e) {
      debugPrint("Live camera frame error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<Uint8List?> _convertYUV420toJPEG(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      // Downsample 2x agar loop piksel 4x lebih cepat
      final int step = (width > 320) ? 2 : 1;
      final int outWidth = width ~/ step;
      final int outHeight = height ~/ step;

      final img.Image rgbImage = img.Image(width: outWidth, height: outHeight);

      for (int y = 0; y < outHeight; y++) {
        final int srcY = y * step;
        for (int x = 0; x < outWidth; x++) {
          final int srcX = x * step;
          final int uvIndex =
              uvPixelStride * (srcX ~/ 2) + uvRowStride * (srcY ~/ 2);
          final int index = srcY * yRowStride + srcX;
          
          if (index < image.planes[0].bytes.length && uvIndex < image.planes[1].bytes.length && uvIndex < image.planes[2].bytes.length) {
            final yp = image.planes[0].bytes[index];
            final up = image.planes[1].bytes[uvIndex];
            final vp = image.planes[2].bytes[uvIndex];
            final r = (yp + 1.370705 * (vp - 128)).clamp(0, 255).toInt();
            final g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).clamp(0, 255).toInt();
            final b = (yp + 1.732446 * (up - 128)).clamp(0, 255).toInt();
            rgbImage.setPixelRgb(x, y, r, g, b);
          }
        }
      }
      return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 65));
    } catch (e) {
      debugPrint("Error during YUV conversion: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Deteksi Real-time',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromRGBO(63, 81, 181, 1),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(63, 81, 181, 1),
                Color.fromRGBO(68, 138, 255, 1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final newOrientation = orientation == Orientation.portrait
              ? DeviceOrientation.portraitUp
              : DeviceOrientation.landscapeLeft;

          if (newOrientation != _currentOrientation) {
            _currentOrientation = newOrientation;
            _cameraController?.lockCaptureOrientation(_currentOrientation);
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_cameraController != null &&
                  _cameraController!.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),

              if (_detections != null && _lastImage != null)
                CustomPaint(
                  painter: BoxOverlayPainter(
                    _lastImage!,
                    _detections!,
                  ),
                ),

              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isProcessing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _isProcessing
                              ? "Menganalisis frame..."
                              : (_detections != null && _detections!.isNotEmpty)
                                  ? "${_detections!.length} Mangga terdeteksi"
                                  : "Mengarahkan kamera...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}