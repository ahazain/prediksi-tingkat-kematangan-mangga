import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _yearController = TextEditingController();
  bool isLoading = false;
  Map<String, dynamic>? summary;

  Future<void> fetchHistory(int year) async {
    setState(() => isLoading = true);
    final url = Uri.parse('https://api.newshub.store/yearly-summary?year=$year');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          summary = json;
          isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  Widget buildCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget buildDistribution(Map data, {required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$label ${e.key}'),
              Text(e.value.toString()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildMonthlyBreakdown(List data) {
    return Column(
      children: data.map<Widget>((entry) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          title: Text('${entry['month_name']} (${entry['month']})'),
          subtitle: Text('Total Mangga: ${entry['total_mangoes']}'),
          trailing: Text('Sesi: ${entry['total_sessions']}'),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Deteksi Mangga"),
        backgroundColor: const Color.fromRGBO(63, 81, 181, 1),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Masukkan Tahun",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(63, 81, 181, 1),
                  ),
                  child: const Text("Lihat"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : summary == null
                    ? const Center(child: Text("Masukkan tahun untuk melihat riwayat"))
                    : summary!['success'] != true
                        ? const Center(child: Text("Tidak ada data riwayat untuk tahun ini"))
                        : RefreshIndicator(
                            onRefresh: () => fetchHistory(int.parse(_yearController.text)),
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              children: [
                                buildCard(
                                  title: "Statistik Umum (${summary!['year']})",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Total Mangga: ${summary!['total_mangoes']}"),
                                      const SizedBox(height: 4),
                                      Text("Total Sesi: ${summary!['total_sessions']}"),
                                    ],
                                  ),
                                ),
                                if (summary!.containsKey('ripeness_distribution'))
                                  buildCard(
                                    title: "Distribusi Kematangan",
                                    child: buildDistribution(
                                      summary!['ripeness_distribution'],
                                      label: 'Tingkat',
                                    ),
                                  ),
                                if (summary!.containsKey('grade_distribution'))
                                  buildCard(
                                    title: "Distribusi Grade",
                                    child: buildDistribution(
                                      summary!['grade_distribution'],
                                      label: 'Grade',
                                    ),
                                  ),
                                if (summary!.containsKey('monthly_breakdown'))
                                  buildCard(
                                    title: "Rangkuman Bulanan",
                                    child: buildMonthlyBreakdown(summary!['monthly_breakdown']),
                                  ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
