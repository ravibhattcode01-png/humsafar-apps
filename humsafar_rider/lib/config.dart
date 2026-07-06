/// Humsafar Rider App configuration.
/// Deployment pe sirf yahan API base URL badalna hai.
class AppConfig {
  /// Laravel backend base URL (bina trailing slash).
  /// Local test:  http://10.0.2.2:8000  (Android emulator -> host machine)
  /// Production:  https://api.humsafar.app
  static const String baseUrl = 'https://humsafar.ngie.in';

  static const String apiUrl = '$baseUrl/api/v1';

  // Humsafar brand colors
  static const int brandGreen = 0xFF0E7C3A;
  static const int brandLime = 0xFF8DC63F;
}
