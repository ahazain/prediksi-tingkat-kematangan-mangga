import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../components/section_title.dart';
import '../components/box_overlay_painter.dart';
import '../components/detection_cards.dart';

class ImageInputPage extends StatefulWidget {
  const ImageInputPage({super.key});
  @override
  State<ImageInputPage> createState() => _ImageInputPageState();
}

class _ImageInputPageState extends State<ImageInputPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;
  Uint8List? _processedImageBytes;
  Map<String, dynamic>? _predictionJson;

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
            _processedImageBytes = null;
            _predictionJson = null;
          });
        } else {
          setState(() {
            _imageFile = File(pickedFile.path);
            _imageBytes = null;
            _processedImageBytes = null;
            _predictionJson = null;
          });
        }

        await _processImage();
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengambil gambar")),
      );
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
        Uri.parse('http://127.0.0.1:5000/predict'),
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
      final contentType = response.headers['content-type'] ?? '';

      if (response.statusCode == 200) {
        if (contentType.contains('image')) {
          setState(() {
            _processedImageBytes = bytes;
            _predictionJson = null;
          });
        } else {
          final responseString = utf8.decode(bytes);
          try {
            final parsed = jsonDecode(responseString);
            if (parsed is Map<String, dynamic>) {
              setState(() {
                _processedImageBytes = null;
                _predictionJson = parsed;
              });
            } else {
              throw Exception("Format tidak dikenali");
            }
          } catch (_) {
            setState(() {
              _processedImageBytes = null;
              _predictionJson = {'hasil': responseString};
            });
          }
        }
      } else {
        throw Exception('Gagal: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error saat kirim gambar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan saat memproses gambar")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _imageBytes != null
        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
        : _imageFile != null
            ? Image.file(_imageFile!, fit: BoxFit.cover)
            : const Center(child: Text("Tidak ada gambar"));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Deteksi Mangga"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(title: "Gambar yang Dipilih"),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade400),
                color: Colors.indigo.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: imageWidget,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_processedImageBytes != null &&
                _predictionJson != null &&
                _predictionJson!.containsKey('detections')) ...[
              const SectionTitle(title: "Hasil Deteksi (Bounding Box)"),
              FutureBuilder<ui.Image>(
                future: decodeImageFromList(_processedImageBytes!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final detections = _predictionJson!['detections'];
                  final image = snapshot.data!;
                  return Container(
                    width: double.infinity,
                    height: image.height.toDouble() * 0.5,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: CustomPaint(
                      painter: BoxOverlayPainter(image, detections),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            if (_predictionJson != null) ...[
              const SectionTitle(title: "Detail Hasil Deteksi"),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _predictionJson!.containsKey('detections')
                    ? DetectionCards(detections: _predictionJson!['detections'])
                    : Column(
                        key: const ValueKey("fallback_json"),
                        children: _predictionJson!.entries.map((entry) {
                          return Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(entry.value.toString()),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],

            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Ambil Foto"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text("Pilih dari Galeri"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
