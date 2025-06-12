import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageInputPage extends StatefulWidget {
  const ImageInputPage({super.key});

  @override
  State<ImageInputPage> createState() => _ImageInputPageState();
}

class _ImageInputPageState extends State<ImageInputPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;

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
          });
        } else {
          setState(() {
            _imageFile = File(pickedFile.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengambil gambar")),
      );
    }
  }

  void _processImage() {
    final hasImage = kIsWeb ? _imageBytes != null : _imageFile != null;
    if (!hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih atau ambil gambar dulu")),
      );
      return;
    }

    // TODO: Tambahkan logika pemrosesan gambar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Memproses gambar...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _imageBytes != null
        ? Image.memory(_imageBytes!, fit: BoxFit.contain)
        : _imageFile != null
            ? Image.file(_imageFile!, fit: BoxFit.contain)
            : const Center(child: Text("Tidak ada gambar"));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Input Gambar"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageWidget,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Ambil Foto"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text("Pilih dari Galeri"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _processImage,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Proses Gambar"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
