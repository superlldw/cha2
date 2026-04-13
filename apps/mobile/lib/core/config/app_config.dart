import 'dart:io' show Platform;

class AppConfig {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}

