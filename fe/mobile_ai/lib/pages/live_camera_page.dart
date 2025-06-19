import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import untuk DeviceOrientation
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../components/box_overlay_painter.dart';

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
  // Variabel untuk menyimpan orientasi perangkat saat ini
  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;

  @override
  void initState() {
    super.initState();
    // Mengunci orientasi potret saat halaman pertama kali dibuka
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeCamera();
  }

  @override
  void dispose() {
    // Mengizinkan semua orientasi lagi saat keluar dari halaman
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
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    // Mengunci orientasi capture awal ke potret
    await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    _cameraController!.startImageStream((CameraImage image) {
      if (!_isProcessing) {
        _isProcessing = true;
        _processCameraImage(image);
      }
    });

    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      // Konversi gambar dari YUV ke JPEG
      Uint8List? jpegBytes = await _convertYUV420toJPEG(image);
      if (jpegBytes == null) {
        _isProcessing = false;
        return;
      }

      // --- PERUBAHAN UTAMA: ROTASI GAMBAR JIKA PERANGKAT POTRET ---
      // Sensor kamera biasanya lanskap, jadi jika perangkat dalam mode potret,
      // kita perlu memutar gambar 90 derajat sebelum mengirim ke backend.
      if (_currentOrientation == DeviceOrientation.portraitUp) {
        final originalImage = img.decodeJpg(jpegBytes);
        if (originalImage != null) {
          final rotatedImage = img.copyRotate(originalImage, angle: 90);
          jpegBytes = Uint8List.fromList(img.encodeJpg(rotatedImage));
        }
      }
      // Jika orientasi lanskap, tidak perlu rotasi.

      // Decode gambar yang sudah benar orientasinya untuk ditampilkan di UI
      _lastImage = await decodeImageFromList(jpegBytes);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.newshub.store/predict'),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'live_frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        final parsed = jsonDecode(responseString);
        if (mounted) {
          setState(() {
            _detections = parsed['detections'];
          });
        }
      } else {
        if (mounted) setState(() => _detections = null);
      }
    } catch (e) {
      debugPrint("Error processing camera image: $e");
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _isProcessing = false;
      });
    }
  }

  Future<Uint8List?> _convertYUV420toJPEG(CameraImage image) async {
    // Fungsi ini tidak berubah, biarkan seperti sebelumnya
    try {
      final int width = image.width;
      final int height = image.height;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;
      final img.Image rgbImage = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex =
              uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * yRowStride + x;
          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];
          final r = (yp + 1.370705 * (vp - 128)).clamp(0, 255).toInt();
          final g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128))
              .clamp(0, 255)
              .toInt();
          final b = (yp + 1.732446 * (up - 128)).clamp(0, 255).toInt();
          rgbImage.setPixelRgb(x, y, r, g, b);
        }
      }
      return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 75));
    } catch (e) {
      debugPrint("Error during YUV to JPEG conversion: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deteksi Real-time'),
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
      // --- PERUBAHAN: MENGGUNAKAN ORIENTATION BUILDER ---
      body: OrientationBuilder(
        builder: (context, orientation) {
          // Tentukan orientasi perangkat
          final newOrientation = orientation == Orientation.portrait
              ? DeviceOrientation.portraitUp
              : DeviceOrientation.landscapeLeft;
          
          // Jika orientasi berubah, perbarui state dan lock orientasi kamera
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
                    // Sesuaikan aspect ratio pratinjau
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
              
              if (_isProcessing)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            "Mendeteksi...",
                            style: TextStyle(color: Colors.white, fontSize: 16),
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