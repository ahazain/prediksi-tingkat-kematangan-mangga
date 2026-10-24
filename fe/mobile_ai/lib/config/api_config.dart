class ApiConfig {
  // Default ke Render Cloud (Aktif & Siap untuk APK di semua device)
  static String baseUrl = 'https://deteksi-mangga-api.onrender.com';

  // Opsi Pengujian Lokal (Localhost / Wi-Fi laptop):
  // static String baseUrl = 'http://192.168.110.60:5000';

  static String get predictUrl => '$baseUrl/predict';
  static String get predictCompareUrl => '$baseUrl/predict-compare';
  static String yearlySummaryUrl(int year) => '$baseUrl/yearly-summary?year=$year';
  static String dailySummaryUrl(String date) => '$baseUrl/yearly-summary?date=$date';
}
