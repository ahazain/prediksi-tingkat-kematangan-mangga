class ApiConfig {
  // IP Wi-Fi Laptop (HP dan Laptop berada di jaringan Wi-Fi yang sama)
  // Tidak perlu kabel USB atau command adb lagi, selama backend running akan langsung terhubung.
  static const String baseUrl = 'http://192.168.1.55:5000';

  // Opsi cadangan jika menggunakan kabel USB dengan adb reverse:
  // static const String baseUrl = 'http://127.0.0.1:5000';

  // OPSI 3: Endpoint production jika sudah di-deploy ke server online
  // static const String baseUrl = 'https://api.newshub.store';

  static String get predictUrl => '$baseUrl/predict';
  static String get predictCompareUrl => '$baseUrl/predict-compare';
  static String yearlySummaryUrl(int year) => '$baseUrl/yearly-summary?year=$year';
  static String dailySummaryUrl(String date) => '$baseUrl/yearly-summary?date=$date';
}
