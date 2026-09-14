class ApiConfig {
  // URL Backend Production di Render.com (Online 24/7 di Cloud Singapore)
  static const String baseUrl = 'https://deteksi-mangga-api.onrender.com';

  // Opsi cadangan lokal jika ingin testing offline di rumah:
  // static const String baseUrl = 'http://192.168.1.55:5000';

  static String get predictUrl => '$baseUrl/predict';
  static String get predictCompareUrl => '$baseUrl/predict-compare';
  static String yearlySummaryUrl(int year) => '$baseUrl/yearly-summary?year=$year';
  static String dailySummaryUrl(String date) => '$baseUrl/yearly-summary?date=$date';
}
