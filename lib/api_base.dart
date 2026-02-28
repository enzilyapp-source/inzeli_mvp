// lib/api_base.dart
import 'package:flutter/foundation.dart';

// Override at run time with:
// flutter run -d chrome  --dart-define=API_BASE_URL=https://inzeli-api-6heq.onrender.com/api
// flutter run -d android --dart-define=API_BASE_URL=https://inzeli-api-6heq.onrender.com/api
const String _defaultApiBase = 'https://inzeli-api-6heq.onrender.com/api';

const String _envApiBase =
    String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBase);

String _androidLoopback(String url) {
  if (!url.contains('localhost') && !url.contains('127.0.0.1')) return url;
  final uri = Uri.parse(url);
  return uri.replace(host: '10.0.2.2').toString();
}

String get apiBase {
  // Web uses the URL as-is
  if (kIsWeb) return _envApiBase;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return _androidLoopback(_envApiBase);
    default:
      return _envApiBase;
  }
}
