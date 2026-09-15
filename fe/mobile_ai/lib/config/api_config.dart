class ApiConfig {
  // Default ke IP Wi-Fi laptop lokal saat ini
  static String baseUrl = 'http://192.168.110.60:5000';

  // Opsi Render Cloud (jika diaktifkan):
  // static String baseUrl = 'https://deteksi-mangga-api.onrender.com';

  static String get predictUrl => '$baseUrl/predict';
  static String get predictCompareUrl => '$baseUrl/predict-compare';
  static String yearlySummaryUrl(int year) => '$baseUrl/yearly-summary?year=$year';
  static String dailySummaryUrl(String date) => '$baseUrl/yearly-summary?date=$date';
}
