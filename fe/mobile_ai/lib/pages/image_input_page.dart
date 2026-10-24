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
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import './live_camera_page.dart';
import '../components/section_title.dart';
import '../components/box_overlay_painter.dart';
import '../components/detection_cards.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:mobile_ai/pages/history_page.dart';
import 'package:mobile_ai/pages/compare_page.dart';
import '../config/api_config.dart';

class ImageInputPage extends StatefulWidget {
  const ImageInputPage({super.key});

  @override
  State<ImageInputPage> createState() => _ImageInputPageState();
}

class _ImageInputPageState extends State<ImageInputPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;
  Map<String, dynamic>? _predictionJson;
  late ValueNotifier<bool> _dialNotifier;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dialNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    _dialNotifier.dispose();
    super.dispose();
  }

  void _showServerDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    String statusMessage = "";
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Color(0xFF2979FF)),
              SizedBox(width: 8),
              Text("Server Backend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Masukkan URL Backend (contoh: https://deteksi-mangga-api.onrender.com):",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  labelText: "Base URL",
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3F2FD),
                  foregroundColor: const Color(0xFF1976D2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isTesting
                    ? null
                    : () async {
                        setDialogState(() {
                          isTesting = true;
                          statusMessage = "Menghubungi server...";
                        });
                        try {
                          final cleanUrl = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
                          final res = await http.get(Uri.parse('$cleanUrl/health')).timeout(const Duration(seconds: 4));
                          if (res.statusCode == 200) {
                            setDialogState(() {
                              isTesting = false;
                              statusMessage = "✅ Terhubung! Server & YOLO Aktif.";
                            });
                          } else {
                            setDialogState(() {
                              isTesting = false;
                              statusMessage = "⚠️ Server merespon kode ${res.statusCode}";
                            });
                          }
                        } catch (err) {
                          setDialogState(() {
                            isTesting = false;
                            statusMessage = "❌ Gagal: HP & Laptop harus 1 Wi-Fi";
                          });
                        }
                      },
                icon: isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_find_rounded),
                label: const Text("Tes Koneksi"),
              ),
              if (statusMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusMessage.startsWith("✅") ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final newUrl = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
                if (newUrl.isNotEmpty) {
                  setState(() {
                    ApiConfig.baseUrl = newUrl;
                  });
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("URL backend disimpan: ${ApiConfig.baseUrl}")),
                );
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    _dialNotifier.value = false; // Tutup SpeedDial
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        // Baca bytes asli dari galeri/kamera
        final rawBytes = await pickedFile.readAsBytes();

        // Jamin kompresi software ke max 512px (mengatasi bug Android Gallery Picker yang sering mengirim file asli 10MB+)
        Uint8List compressedBytes = rawBytes;
        try {
          final decoded = img.decodeImage(rawBytes);
          if (decoded != null) {
            if (decoded.width > 512 || decoded.height > 512) {
              final resized = img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? 512 : null,
                height: decoded.height > decoded.width ? 512 : null,
              );
              compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
            } else {
              compressedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 70));
            }
          }
        } catch (compressErr) {
          debugPrint("[COMPRESS LOCAL ERROR] $compressErr");
        }

        setState(() {
          _imageBytes = compressedBytes;
          _imageFile = null;
          _predictionJson = null;
        });

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
    final hasImage = _imageBytes != null || _imageFile != null;

    if (!hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih atau ambil gambar dulu")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── STEP 1: Upload gambar → server langsung balas job_id (<1 detik) ──
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.predictUrl),
      );

      // Selalu kirim bytes terkompresi (~30KB) agar upload instan <1 detik
      if (_imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          _imageBytes!,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _imageFile!.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      // Upload timeout 60 detik (sangat cukup untuk file 30KB)
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final uploadResponse = await http.Response.fromStream(streamedResponse);

      if (uploadResponse.statusCode != 202) {
        throw Exception(
            'Upload gagal, kode: ${uploadResponse.statusCode}\n${uploadResponse.body}');
      }

      final uploadJson = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
      final jobId = uploadJson['job_id'] as String?;
      if (jobId == null) throw Exception('Server tidak mengirim job_id');

      // ── STEP 2: Polling /result/<job_id> setiap 3 detik, max 3 menit ──
      const maxWait = Duration(minutes: 3);
      const pollInterval = Duration(seconds: 3);
      final deadline = DateTime.now().add(maxWait);

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
        if (!mounted) return;

        try {
          final pollRes = await http
              .get(Uri.parse('${ApiConfig.baseUrl}/result/$jobId'))
              .timeout(const Duration(seconds: 15));

          if (pollRes.statusCode == 202) {
            // Masih processing — lanjut polling
            continue;
          }

          final contentType = pollRes.headers['content-type'] ?? '';
          if (pollRes.statusCode == 200 &&
              contentType.contains('application/json')) {
            final parsed = jsonDecode(pollRes.body);
            if (parsed is Map<String, dynamic>) {
              if (mounted) setState(() => _predictionJson = parsed);
              return; // Selesai!
            }
          } else if (pollRes.statusCode >= 500) {
            final errBody = pollRes.body;
            throw Exception('Server error (${pollRes.statusCode}): $errBody');
          }
        } catch (pollErr) {
          debugPrint("Polling retry (server sibuk): $pollErr");
          continue;
        }
      }

      // Timeout polling
      throw Exception(
          'Waktu tunggu habis (3 menit). Coba lagi saat server tidak sibuk.');
    } catch (e) {
      debugPrint("Error saat kirim gambar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menganalisis: $e"),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildGradientCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
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
              Text("Belum ada gambar", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              const SizedBox(height: 5),
              const Text(
                "Silakan ambil atau pilih gambar untuk mulai deteksi mangga",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          );

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromRGBO(63, 81, 181, 1), Color.fromRGBO(68, 138, 255, 1)],
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
            if (_isLoading)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 40),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
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
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFF2979FF),
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Menganalisis Kematangan...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Chillax',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Model AI YOLOv8 di server cloud sedang memproses deteksi dan grading kematangan (memerlukan waktu ~45-60 detik). Harap tunggu...",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                    ),
                  ],
                ),
              )
            else if (_imageBytes == null && _imageFile == null)
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
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_search_rounded, size: 100, color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        "Ayo ukur tingkat kematangan manggamu!",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
            if (_predictionJson != null && _predictionJson!.containsKey('detections')) ...[
              const SizedBox(height: 24),
              const SectionTitle(title: "Hasil Deteksi", color: Colors.white),
              FutureBuilder<ui.Image>(
                future: _loadImageForPainting(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
              const SectionTitle(title: "Detail Hasil Deteksi", color: Colors.white),
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
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: const Color.fromRGBO(63, 81, 181, 1),
        foregroundColor: Colors.white,
        overlayOpacity: 0,
        spacing: 12,
        spaceBetweenChildren: 12,
        openCloseDial: _dialNotifier,
        children: [
          SpeedDialChild(
            label: 'Live Kamera',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: _buildGradientCircleButton(
              icon: Icons.videocam,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LiveCameraPage()),
                );
              },
            ),
          ),
          SpeedDialChild(
            label: 'Ambil Foto',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: _buildGradientCircleButton(
              icon: Icons.camera_alt,
              onTap: () => _pickImage(ImageSource.camera),
            ),
          ),
          SpeedDialChild(
            label: 'Pilih dari Galeri',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: _buildGradientCircleButton(
              icon: Icons.photo_library,
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ),
          // KODE BARU (BENAR)
          SpeedDialChild(
            label: 'Riwayat Foto',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: _buildGradientCircleButton(
              icon: Icons.history,
              onTap: () {
                _dialNotifier.value = false;
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage()));
              },
            ),
          ),
          SpeedDialChild(
            label: 'Compare',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: _buildGradientCircleButton(
              icon: Icons.compare_arrows,
              onTap: () {
                _dialNotifier.value = false;
                if ((_imageFile != null || _imageBytes != null)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComparePage(
                        imageFile: _imageFile,
                        imageBytes: _imageBytes,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Harap pilih gambar terlebih dahulu.")),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
