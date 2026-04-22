import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // ???????????????????????????
      return 'http://10.18.28.83:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}
