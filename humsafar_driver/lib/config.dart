/// Humsafar Driver App configuration.
class AppConfig {
  /// Laravel backend base URL (bina trailing slash).
  /// Local test:  http://10.0.2.2:8000
  /// Production:  https://api.humsafar.app
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const String apiUrl = '$baseUrl/api/v1';

  static const int brandGreen = 0xFF0E7C3A;
  static const int brandDark = 0xFF116230;
}
