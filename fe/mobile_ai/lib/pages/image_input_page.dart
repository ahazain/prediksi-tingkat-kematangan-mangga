// Import tetap seperti sebelumnya
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:camera/camera.dart';
import 'package:mobile_ai/pages/live_detection_pages.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../components/section_title.dart';
import '../components/box_overlay_painter.dart';
import '../components/detection_cards.dart';

class ImageInputPage extends StatefulWidget {
  const ImageInputPage({super.key});
  @override
  State<ImageInputPage> createState() => _ImageInputPageState();
}

class _ImageInputPageState extends State<ImageInputPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  List<CameraDescription>? _cameras;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;
  Map<String, dynamic>? _predictionJson;
  Widget _buildRoundedButton({
    required IconData icon,
    required String label,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color2.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _initCamera() async {
  //   _cameras = await availableCameras();
  //   final backCamera = _cameras!.firstWhere(
  //     (camera) => camera.lensDirection == CameraLensDirection.back,
  //   );

  //   _cameraController = CameraController(
  //     backCamera,
  //     ResolutionPreset.medium,
  //     enableAudio: false,
  //   );

  //   await _cameraController!.initialize();

  //   _cameraController!.startImageStream((CameraImage image) async {
  //     if (_isDetecting) return;
  //     _isDetecting = true;

  //     try {
  //       // Convert YUV -> JPEG -> Uint8List
  //       final bytes = await convertYUV420toImage(image);
  //       await _sendImageBytesToBackend(bytes);
  //     } finally {
  //       _isDetecting = false;
  //     }
  //   });

  //   setState(() {});
  // }

  // Future<Uint8List> convertYUV420toImage(CameraImage image) async {
  //   final int width = image.width;
  //   final int height = image.height;
  //   final yRowStride = image.planes[0].bytesPerRow;
  //   final uvRowStride = image.planes[1].bytesPerRow;
  //   final uvPixelStride = image.planes[1].bytesPerPixel!;

  //   final img.Image rgbImage = img.Image(width, height);

  //   for (int y = 0; y < height; y++) {
  //     for (int x = 0; x < width; x++) {
  //       final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
  //       final int index = y * yRowStride + x;

  //       final yp = image.planes[0].bytes[index];
  //       final up = image.planes[1].bytes[uvIndex];
  //       final vp = image.planes[2].bytes[uvIndex];

  //       final r = (yp + 1.370705 * (vp - 128)).clamp(0, 255).toInt();
  //       final g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128))
  //           .clamp(0, 255)
  //           .toInt();
  //       final b = (yp + 1.732446 * (up - 128)).clamp(0, 255).toInt();

  //       rgbImage.setPixelRgb(x, y, r, g, b);
  //     }
  //   }

  //   final jpg = img.encodeJpg(rgbImage, quality: 85);
  //   return Uint8List.fromList(jpg);
  // }

  // Future<void> _sendImageBytesToBackend(Uint8List imageBytes) async {
  //   try {
  //     var request = http.MultipartRequest(
  //       'POST',
  //       Uri.parse('https://api.newshub.store/predict'),
  //     );

  //     request.files.add(
  //       http.MultipartFile.fromBytes(
  //         'image',
  //         imageBytes,
  //         filename: 'frame.jpg',
  //         contentType: MediaType('image', 'jpeg'),
  //       ),
  //     );

  //     final response = await request.send();
  //     final bytes = await response.stream.toBytes();
  //     final responseString = utf8.decode(bytes);

  //     if (response.statusCode == 200) {
  //       final parsed = jsonDecode(responseString);
  //       setState(() {
  //         _predictionJson = parsed;
  //       });
  //     } else {
  //       debugPrint("Error: ${response.statusCode}");
  //     }
  //   } catch (e) {
  //     debugPrint("Live stream upload error: $e");
  //   }
  // }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
            _predictionJson = null;
          });
        } else {
          setState(() {
            _imageFile = File(pickedFile.path);
            _imageBytes = null;
            _predictionJson = null;
          });
        }

        await _processImage();
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar")));
    }
  }

  Future<void> _processImage() async {
    final hasImage = kIsWeb ? _imageBytes != null : _imageFile != null;

    if (!hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih atau ambil gambar dulu")),
      );
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.newshub.store/predict'),
      );

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            _imageBytes!,
            filename: 'image.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            _imageFile!.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await request.send();
      final bytes = await response.stream.toBytes();
      final responseString = utf8.decode(bytes);
      final contentType = response.headers['content-type'] ?? '';

      // DEBUG LOG:
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Content-Type: $contentType');
      debugPrint('Response body: $responseString');

      if (response.statusCode == 200 &&
          contentType.contains('application/json')) {
        final parsed = jsonDecode(responseString);
        if (parsed is Map<String, dynamic>) {
          setState(() {
            _predictionJson = parsed;
          });
        } else {
          throw Exception('Format JSON tidak sesuai');
        }
      } else {
        throw Exception('Response bukan JSON: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error saat kirim gambar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Terjadi kesalahan saat memproses gambar"),
        ),
      );
    }
  }

  Future<ui.Image> _loadImageForPainting() async {
    if (_imageBytes != null) {
      return decodeImageFromList(_imageBytes!);
    } else if (_imageFile != null) {
      final bytes = await _imageFile!.readAsBytes();
      return decodeImageFromList(bytes);
    } else {
      throw Exception("Tidak ada gambar untuk decoding.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = (_imageBytes != null || _imageFile != null)
        ? (_imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
              : Image.file(_imageFile!, fit: BoxFit.cover))
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 100, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text(
                "Belum ada gambar",
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 5),
              const Text(
                "Silakan ambil atau pilih gambar untuk mulai deteksi mangga",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          );

    return Scaffold(
      extendBody: true, // ✅ Agar bagian bawah transparan menyatu ke body
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
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
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: const Text(
              "Deteksi Mangga",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Chillax',
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imageBytes == null && _imageFile == null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 100),
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A93F8), Color(0xFF56C5F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.image_search_rounded,
                        size: 100,
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Ayo ukur tingkat kematangan manggamu!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Ambil atau pilih gambar untuk melihat hasil deteksi",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

            if (_predictionJson != null &&
                _predictionJson!.containsKey('detections')) ...[
              const SizedBox(height: 24),
              const SectionTitle(title: "Hasil Deteksi", color: Colors.white),
              FutureBuilder<ui.Image>(
                future: _loadImageForPainting(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final detections = _predictionJson!['detections'];
                  final image = snapshot.data!;
                  final aspectRatio = image.width / image.height;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: CustomPaint(
                          painter: BoxOverlayPainter(image, detections),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            if (_predictionJson != null &&
                _predictionJson!.containsKey('detections')) ...[
              const SectionTitle(
                title: "Detail Hasil Deteksi",
                color: Colors.white,
              ),
              const SizedBox(height: 10),
              FutureBuilder<ui.Image>(
                future: _loadImageForPainting(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final image = snapshot.data!;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final padding = 40.0;
                  final displayWidth = screenWidth - padding;

                  return DetectionCards(
                    detections: _predictionJson!['detections'],
                    originalWidth: image.width,
                    originalHeight: image.height,
                    displayWidth: displayWidth,
                  );
                },
              ),
            ],
          ],
        ),
      ),

      // ✅ Transparan bottomNavigationBar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRoundedButton(
                icon: Icons.videocam,
                label: "Live Kamera",
                color1: const Color.fromRGBO(63, 81, 181, 1),
                color2: const Color.fromRGBO(68, 138, 255, 1),
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LiveDetectionPage(),
                    ), // Nama halaman baru kita
                  );
                },
              ),
              // TAMBAHKAN JARAK DI SINI
              const SizedBox(height: 12),
              // _buildRoundedButton(
              //   icon: Icons.camera_alt,
              //   label: "Ambil Foto",
              //   color1: const ui.Color.fromRGBO(63, 81, 181, 1),
              //   color2: const ui.Color.fromRGBO(68, 138, 255, 1),
              //   onTap: () => _pickImage(ImageSource.camera),
              // ),
              const SizedBox(height: 12),
              _buildRoundedButton(
                icon: Icons.photo_library,
                label: "Pilih dari Galeri",
                color1: const ui.Color.fromRGBO(63, 81, 181, 1),
                color2: const ui.Color.fromRGBO(68, 138, 255, 1),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
