import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _yearController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _summaryData;

  Future<void> _fetchSummary(String year) async {
    setState(() {
      _loading = true;
      _summaryData = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.newshub.store/yearly-summary?year=$year'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          setState(() {
            _summaryData = jsonData;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data tidak ditemukan')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat memuat data')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildDistribution(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(e.value.toString()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyBreakdown(List<dynamic> months) {
    return Column(
      children: months.map((monthData) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: Text("Bulan: ${monthData['month_name']}"),
            subtitle: Text(
                "Total Mangga: ${monthData['total_mangoes']} | Sesi: ${monthData['total_sessions']}"),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }
  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: 0.5,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 2, width: 36, color: Color(0xFF1565C0)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _styledBox(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Deteksi",),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Masukkan Tahun:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: "Contoh: 2025",
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (_yearController.text.isNotEmpty) {
                            _fetchSummary(_yearController.text.trim());
                            FocusScope.of(context).unfocus();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                        ),
                        child: const Text("Cari"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_summaryData != null)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Ringkasan Tahun"),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.bar_chart, color: Color(0xFF1565C0)),
                      title: Text("Tahun: ${_summaryData!['year']}"),
                      subtitle: Text(
                        "Total Mangga: ${_summaryData!['total_mangoes']} | Total Sesi: ${_summaryData!['total_sessions']}",
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle("Distribusi Tingkat Kematangan"),
                  _styledBox(_buildDistribution(Map<String, dynamic>.from(
                      _summaryData!['ripeness_distribution']))),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Distribusi Grade"),
                  _styledBox(_buildDistribution(Map<String, dynamic>.from(
                      _summaryData!['grade_distribution']))),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Ringkasan Bulanan"),
                  _buildMonthlyBreakdown(_summaryData!['monthly_breakdown']),
                ],
              ),
            )

          ],
        ),
      ),
    ),

    resizeToAvoidBottomInset: true,

    );
  }
}
