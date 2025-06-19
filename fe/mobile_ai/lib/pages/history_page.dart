// File: history_page.dart (Desain Baru & Modern)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // Diperlukan untuk animasi

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // ===========================================================================
  // == BAGIAN LOGIKA & STATE (TIDAK DIUBAH, SESUAI KODE ASLI ANDA) ===========
  // ===========================================================================
  final TextEditingController _yearController = TextEditingController();
  bool isLoading = false;
  Map<String, dynamic>? summary;

  Future<void> fetchHistory(int year) async {
    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);
    final url = Uri.parse('https://api.newshub.store/yearly-summary?year=$year');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Logika decode dan set-state Anda tetap dipertahankan
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
           setState(() {
            summary = jsonData['data'];
            isLoading = false;
          });
        } else {
           setState(() {
            summary = null; // Pastikan summary null jika data tidak ditemukan
            isLoading = false;
          });
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data untuk tahun ini')),
          );
        }
      } else {
        throw Exception('Gagal memuat data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() {
         summary = null;
         isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }
  // ===========================================================================
  // == AKHIR DARI BAGIAN LOGIKA & STATE ======================================
  // ===========================================================================


  // WIDGET UTAMA
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Latar belakang abu-abu lembut
      appBar: AppBar(
        title: const Text("Riwayat Deteksi", style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
      body: Column(
        children: [
          _buildSearchHeader(), // Header pencarian yang didesain ulang
          Expanded(
            // AnimatedSwitcher untuk transisi halus antar state
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // == BAGIAN UI (WIDGET HELPER) =============================================
  // ===========================================================================

  /// Widget untuk header pencarian
  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2979FF), Color(0xFF3D5AFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        )
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Masukkan Tahun...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                prefixIcon: Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.8)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              final input = int.tryParse(_yearController.text);
              if (input != null) {
                fetchHistory(input);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Tahun tidak valid")),
                );
              }
            },
            icon: const Icon(Icons.search),
            label: const Text("Lihat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3D5AFE),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Menentukan konten mana yang akan ditampilkan
  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summary != null) {
      return _buildResultsView(summary!);
    }
    return _buildEmptyState();
  }

  /// Tampilan saat halaman pertama kali dibuka
  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu_rounded, size: 120, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              "Jelajahi Riwayat Anda",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Text(
              "Masukkan tahun di atas untuk melihat ringkasan data deteksi.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan daftar hasil jika data ditemukan
  Widget _buildResultsView(Map<String, dynamic> data) {
    // Menggunakan RefreshIndicator agar pengguna bisa menarik layar untuk refresh data
    return RefreshIndicator(
      key: ValueKey(data['year']), // Memberi key unik agar widget di-rebuild
      onRefresh: () => fetchHistory(int.parse(_yearController.text)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(data),
          if (data.containsKey('ripeness_distribution'))
            _buildDistributionCard("Distribusi Kematangan", data['ripeness_distribution'], data['total_mangoes']),
          if (data.containsKey('grade_distribution'))
            _buildDistributionCard("Distribusi Grade", data['grade_distribution'], data['total_mangoes']),
          if (data.containsKey('monthly_breakdown'))
            _buildMonthlyBreakdownCard(data['monthly_breakdown']),
        ],
      ),
    );
  }

  /// Kartu untuk Ringkasan Umum
  Widget _buildSummaryCard(Map<String, dynamic> data) {
    return AnimatedListItem(
      index: 0,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(Icons.eco, data['total_mangoes'].toString(), "Total Mangga"),
              Container(width: 1, height: 60, color: Colors.grey[200]),
              _buildSummaryItem(Icons.camera_alt, data['total_sessions'].toString(), "Total Sesi"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 36, color: const Color(0xFF3D5AFE)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  /// Kartu untuk menampilkan distribusi dengan progress bar
  Widget _buildDistributionCard(String title, Map<String, dynamic> distribution, int total) {
     final colors = [Colors.green, Colors.orange, Colors.red, Colors.blue, Colors.purple, Colors.teal];
    int colorIndex = 0;

    return AnimatedListItem(
      index: title == "Distribusi Kematangan" ? 1 : 2,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...distribution.entries.map((e) {
                final color = colors[colorIndex % colors.length];
                colorIndex++;
                return _buildDistributionItem(label: e.key, value: e.value, total: total, color: color);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionItem({required String label, required int value, required int total, required Color color}) {
    double percentage = total > 0 ? value / total : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu untuk Rangkuman Bulanan
  Widget _buildMonthlyBreakdownCard(List<dynamic> months) {
    return AnimatedListItem(
      index: 3,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Rangkuman Bulanan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...months.map<Widget>((entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF3D5AFE).withOpacity(0.1),
                    child: Text(
                      entry['month_name'].substring(0, 3),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3D5AFE)),
                    ),
                  ),
                  title: Text(entry['month_name']),
                  subtitle: Text('Total Mangga: ${entry['total_mangoes']}'),
                  trailing: Text('Sesi: ${entry['total_sessions']}', style: TextStyle(color: Colors.grey[700])),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget custom untuk animasi item list
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedListItem({super.key, required this.child, required this.index});

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _animate ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        transform: Matrix4.translationValues(0, _animate ? 0 : 30, 0),
        child: widget.child,
      ),
    );
  }
}