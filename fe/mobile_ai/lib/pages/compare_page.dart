import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../components/box_overlay_painter.dart';
import '../components/detection_cards.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchComparison();
    _uiImage = _loadImage();
  }

  Future<ui.Image> _loadImage() async {
    final bytes = widget.imageBytes ?? await widget.imageFile!.readAsBytes();
    return decodeImageFromList(bytes);
  }

  Future<void> _fetchComparison() async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.newshub.store/predict-compare'),
      );

      if (widget.imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            widget.imageBytes!,
            filename: 'compare.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            widget.imageFile!.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        setState(() {
          compareResult = jsonDecode(resBody);
        });
      } else {
        throw Exception("Gagal menerima data compare.");
      }
    } catch (e) {
      debugPrint("Compare error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengambil data compare")),
      );
    }
  }

  Widget _buildDetectionBox(String title, String key, ui.Image image) {
    final aspectRatio = image.width / image.height;
    final detections = compareResult![key]['detections'] as List;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF3D5AFE),
              ),
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
              displayWidth:
                  MediaQuery.of(context).size.width - 64, // padding 32 * 2
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
        title: const Text("Perbandingan Deteksi"),
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
      body: compareResult == null
          ? const Center(child: CircularProgressIndicator())
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
                      _buildDetectionBox("DIoU-NMS", 'diou_nms', image),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
