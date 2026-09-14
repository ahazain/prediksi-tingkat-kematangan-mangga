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
  DateTime _selectedDate = DateTime.now();
  final int _selectedYear = DateTime.now().year;
  bool _isYearMode = false;
  bool isLoading = false;
  Map<String, dynamic>? summary;

  @override
  void initState() {
    super.initState();
    // Default isi riwayat langsung memuat data hari ini tanpa perlu pilih manual
    fetchHistory(date: _selectedDate);
  }

  String _formatIsoDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatIndonesianDate(DateTime dt) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> fetchHistory({DateTime? date, int? year}) async {
    setState(() => isLoading = true);

    String urlString;
    if (year != null) {
      urlString = ApiConfig.yearlySummaryUrl(year);
    } else {
      final targetDate = date ?? _selectedDate;
      urlString = ApiConfig.dailySummaryUrl(_formatIsoDate(targetDate));
    }

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

  Future<void> _openCalendarPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'PILIH TANGGAL RIWAYAT FOTO',
      cancelText: 'BATAL',
      confirmText: 'PILIH TANGGAL',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3D5AFE),
              onPrimary: Colors.white,
              onSurface: Color(0xFF263238),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isYearMode = false;
      });
      fetchHistory(date: picked);
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
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text(
              "Khusus input Gambar / Foto",
              style: TextStyle(fontSize: 12, color: Colors.white70),
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
            onPressed: () {
              if (_isYearMode) {
                fetchHistory(year: _selectedYear);
              } else {
                fetchHistory(date: _selectedDate);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBanner(),
          _buildCalendarHeader(),
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
              "Riwayat ini hanya mencatat hasil deteksi dari Foto (Ambil Foto & Galeri). Deteksi Live Camera tidak disimpan.",
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

  /// Header kalender interaktif tanpa input keyboard
  Widget _buildCalendarHeader() {
    final bool isSelectedToday = _isToday(_selectedDate) && !_isYearMode;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Pemilih Kalender (Klik untuk memunculkan kalender datepicker)
          InkWell(
            onTap: _openCalendarPicker,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D5AFE).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF3D5AFE),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isYearMode
                                  ? "FILTER TAHUNAN"
                                  : (isSelectedToday ? "HARI INI (DEFAULT)" : "TANGGAL TERPILIH"),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelectedToday ? Colors.green[700] : Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isSelectedToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isYearMode
                              ? "Tahun $_selectedYear"
                              : _formatIndonesianDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Pilih",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3D5AFE),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF3D5AFE)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips Cepat (Tinggal klik langsung ganti tanpa keyboard)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip(
                  label: "Hari Ini",
                  icon: Icons.today_rounded,
                  isActive: isSelectedToday,
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _selectedDate = now;
                      _isYearMode = false;
                    });
                    fetchHistory(date: now);
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  label: "Kemarin",
                  icon: Icons.history_rounded,
                  isActive: !_isYearMode &&
                      _selectedDate.day == DateTime.now().subtract(const Duration(days: 1)).day &&
                      _selectedDate.month == DateTime.now().month &&
                      _selectedDate.year == DateTime.now().year,
                  onTap: () {
                    final yesterday = DateTime.now().subtract(const Duration(days: 1));
                    setState(() {
                      _selectedDate = yesterday;
                      _isYearMode = false;
                    });
                    fetchHistory(date: yesterday);
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  label: "Buka Kalender",
                  icon: Icons.edit_calendar_rounded,
                  isActive: false,
                  onTap: _openCalendarPicker,
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  label: "Semua Tahun $_selectedYear",
                  icon: Icons.calendar_view_month_rounded,
                  isActive: _isYearMode,
                  onTap: () {
                    setState(() {
                      _isYearMode = true;
                    });
                    fetchHistory(year: _selectedYear);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF3D5AFE) : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF3D5AFE) : Colors.white,
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
            Text("Memuat data riwayat foto...", style: TextStyle(color: Colors.grey)),
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
        message: "Data riwayat deteksi foto tidak tersedia untuk periode ini.",
      );
    }

    final data = summary!;
    final int totalSessions = data['total_sessions'] ?? 0;
    final int totalMangoes = data['total_mangoes'] ?? 0;

    if (totalSessions == 0 && totalMangoes == 0) {
      return _buildEmptyState(
        title: "Belum Ada Riwayat Deteksi",
        message: _isYearMode
            ? "Belum ada sesi foto mangga yang tersimpan di tahun $_selectedYear."
            : "Belum ada sesi foto mangga yang tersimpan pada ${_formatIndonesianDate(_selectedDate)}.",
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF3D5AFE),
      onRefresh: () async {
        if (_isYearMode) {
          await fetchHistory(year: _selectedYear);
        } else {
          await fetchHistory(date: _selectedDate);
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildSummaryCard(data),
          if (data.containsKey('ripeness_distribution') && (data['ripeness_distribution'] as Map).isNotEmpty)
            _buildDistributionCard("Distribusi Kematangan", data['ripeness_distribution'], totalMangoes),
          if (data.containsKey('grade_distribution') && (data['grade_distribution'] as Map).isNotEmpty)
            _buildDistributionCard("Distribusi Grade Mutu", data['grade_distribution'], totalMangoes),
          if (data.containsKey('breakdown') && (data['breakdown'] as List).isNotEmpty)
            _buildBreakdownCard(
              title: data['breakdown_title'] ?? "Rincian Waktu Deteksi",
              items: data['breakdown'] as List,
              isYearly: _isYearMode,
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
                Icons.calendar_today_outlined,
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
              onPressed: () {
                final now = DateTime.now();
                setState(() {
                  _selectedDate = now;
                  _isYearMode = false;
                });
                fetchHistory(date: now);
              },
              icon: const Icon(Icons.today),
              label: const Text("Tampilkan Hari Ini"),
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
    required bool isYearly,
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
              final label = isYearly ? (entry['label'] ?? 'Bulan ${entry['month']}') : (entry['time_label'] ?? 'Jam ${entry['hour']}:00');
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
                      child: Icon(
                        isYearly ? Icons.calendar_today : Icons.access_time_rounded,
                        size: 16,
                        color: const Color(0xFF3D5AFE),
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
