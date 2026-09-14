// history_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool isLoading = false;
  Map<String, dynamic>? summary;

  @override
  void initState() {
    super.initState();
    // Otomatis langsung memuat data deteksi foto HARI INI
    fetchTodayHistory();
  }

  String _formatIsoDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatIndonesianToday() {
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  Future<void> fetchTodayHistory() async {
    setState(() => isLoading = true);

    final todayIso = _formatIsoDate(DateTime.now());
    final urlString = ApiConfig.dailySummaryUrl(todayIso);

    try {
      final response = await http.get(Uri.parse(urlString));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          summary = jsonData;
          isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data (HTTP ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        summary = null;
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Koneksi Gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Riwayat Deteksi Foto",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "Data Hari Ini (Reset Otomatis Tiap 2 Hari)",
              style: TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2979FF), Color(0xFF3D5AFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Muat Ulang",
            icon: const Icon(Icons.refresh),
            onPressed: fetchTodayHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBanner(),
          _buildTodayHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner penegasan bahwa riwayat ini khusus untuk deteksi foto
  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        border: Border(
          bottom: BorderSide(color: Colors.blue.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF3D5AFE)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Riwayat ini khusus mencatat hasil foto (Ambil Foto & Galeri). Live Camera bersifat real-time dan tidak disimpan.",
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.blueGrey[900],
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header tanggal hari ini (bersih tanpa tombol filter manual)
  Widget _buildTodayHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2979FF), Color(0xFF3D5AFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x332979FF),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.today_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "DATA HARI INI",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatIndonesianToday(),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Otomatis dibersihkan berkala tiap 2 hari",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3D5AFE)),
            SizedBox(height: 12),
            Text("Memuat data deteksi hari ini...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (summary == null) {
      return _buildEmptyState(
        title: "Gagal Memuat Data",
        message: "Periksa koneksi backend atau pastikan server Flask berjalan.",
      );
    }

    if (summary!['success'] != true) {
      return _buildEmptyState(
        title: "Riwayat Tidak Ditemukan",
        message: "Data riwayat deteksi foto tidak tersedia saat ini.",
      );
    }

    final data = summary!;
    final int totalSessions = data['total_sessions'] ?? 0;
    final int totalMangoes = data['total_mangoes'] ?? 0;

    if (totalSessions == 0 && totalMangoes == 0) {
      return _buildEmptyState(
        title: "Belum Ada Deteksi Hari Ini",
        message: "Silakan ambil foto atau unggah gambar mangga untuk melihat hasil analisis hari ini.",
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF3D5AFE),
      onRefresh: fetchTodayHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildSummaryCard(data),
          if (data.containsKey('ripeness_distribution') && (data['ripeness_distribution'] as Map).isNotEmpty)
            _buildDistributionCard("Distribusi Kematangan Hari Ini", data['ripeness_distribution'], totalMangoes),
          if (data.containsKey('grade_distribution') && (data['grade_distribution'] as Map).isNotEmpty)
            _buildDistributionCard("Distribusi Grade Mutu Hari Ini", data['grade_distribution'], totalMangoes),
          if (data.containsKey('breakdown') && (data['breakdown'] as List).isNotEmpty)
            _buildBreakdownCard(
              title: data['breakdown_title'] ?? "Rincian Jam Deteksi Hari Ini",
              items: data['breakdown'] as List,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String message}) {
    return Center(
      key: const ValueKey('empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchTodayHistory,
              icon: const Icon(Icons.refresh),
              label: const Text("Muat Ulang"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5AFE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    final totalMangoes = data['total_mangoes']?.toString() ?? '0';
    final totalSessions = data['total_sessions']?.toString() ?? '0';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              icon: Icons.eco_rounded,
              value: totalMangoes,
              label: "Total Mangga",
              iconColor: const Color(0xFF10B981),
            ),
            Container(width: 1, height: 60, color: Colors.grey[200]),
            _buildSummaryItem(
              icon: Icons.camera_alt_rounded,
              value: totalSessions,
              label: "Sesi Foto",
              iconColor: const Color(0xFF3D5AFE),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDistributionCard(String title, Map<String, dynamic> distribution, int total) {
    final Map<String, Color> customColors = {
      'matang': const Color(0xFF10B981),
      'sangat matang': const Color(0xFFD97706),
      'mengkal': const Color(0xFFF59E0B),
      'mentah': const Color(0xFFEF4444),
      'sangat mentah': const Color(0xFF991B1B),
      'A': const Color(0xFF3D5AFE),
      'B': const Color(0xFF06B6D4),
      'C': const Color(0xFF8B5CF6),
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D5AFE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...distribution.entries.map((e) {
              final color = customColors[e.key] ?? Colors.indigo;
              final count = e.value as int;
              final percentage = total > 0 ? (count / total) : 0.0;
              final percentText = (percentage * 100).toStringAsFixed(1);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              e.key.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        Text(
                          "$count mangga ($percentText%)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 8,
                        backgroundColor: color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required List<dynamic> items,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D5AFE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map<Widget>((entry) {
              final label = entry['time_label'] ?? 'Jam ${entry['hour']}:00';
              final totalMangoes = entry['total_mangoes'] ?? 0;
              final totalSessions = entry['total_sessions'] ?? 0;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D5AFE).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Color(0xFF3D5AFE),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            "Total mangga: $totalMangoes",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        "$totalSessions sesi foto",
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF3D5AFE)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
