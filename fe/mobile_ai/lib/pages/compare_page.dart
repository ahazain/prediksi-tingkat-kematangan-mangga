import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import '../components/box_overlay_painter.dart';
import '../components/detection_cards.dart';
import '../config/api_config.dart';

class ComparePage extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;

  const ComparePage({super.key, this.imageFile, this.imageBytes});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  Map<String, dynamic>? compareResult;
  late Future<ui.Image> _uiImage;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _uiImage = _loadImage();
    _fetchComparison();
  }

  Future<ui.Image> _loadImage() async {
    final bytes = widget.imageBytes ?? await widget.imageFile!.readAsBytes();
    return decodeImageFromList(bytes);
  }

  Future<void> _fetchComparison() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Dapatkan bytes gambar
      Uint8List rawBytes = widget.imageBytes ?? await widget.imageFile!.readAsBytes();

      // 2. Kompresi cepat di memori HP agar upload ringan (<40KB)
      Uint8List uploadBytes = rawBytes;
      try {
        final decoded = img.decodeImage(rawBytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 480);
          uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
        }
      } catch (e) {
        debugPrint("[COMPRESS COMPARE WARNING] $e");
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.predictCompareUrl),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          uploadBytes,
          filename: 'compare.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedRes = await request.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            compareResult = parsed;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Server merespons kode: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Compare error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengambil data compare: $e")),
        );
      }
    }
  }

  Widget _buildDetectionBox(String title, String key, ui.Image image) {
    final aspectRatio = image.width / image.height;
    final detections = compareResult![key]['detections'] as List;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2979FF),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${detections.length} Mangga",
                    style: const TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: BoxOverlayPainter(image, detections),
                  child: Container(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DetectionCards(
              detections: detections,
              originalWidth: image.width,
              originalHeight: image.height,
              displayWidth: MediaQuery.of(context).size.width - 64,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Perbandingan NMS"),
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2979FF), Color(0xFF3D5AFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2979FF), strokeWidth: 3),
                    SizedBox(height: 20),
                    Text(
                      "Membandingkan Deteksi...",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Menjalankan perbandingan NMS Default vs DIoU-NMS di cloud. Harap tunggu ~5-8 detik.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 54, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          "Gagal memuat perbandingan: $_errorMessage",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchComparison,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Coba Lagi"),
                        ),
                      ],
                    ),
                  ),
                )
              : FutureBuilder<ui.Image>(
                  future: _uiImage,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final image = snapshot.data!;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildDetectionBox("Default NMS", 'default_nms', image),
                          _buildDetectionBox("DIoU-NMS (Lebih Akurat)", 'diou_nms', image),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
