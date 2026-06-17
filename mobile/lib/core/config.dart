/// Application-wide configuration.
class AppConfig {
  /// Base URL of the Django API. Override at build/run time with:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.org/api/v1
  ///
  /// Defaults to localhost for the web target (Chrome). For an Android
  /// emulator use http://10.0.2.2:8000/api/v1.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
}
