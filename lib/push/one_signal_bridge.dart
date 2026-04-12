import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalBridge {
  static const String _appId =
      String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
  static bool _initialized = false;

  static Future<void> syncSignedInUser(String? userId) async {
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) return;
    if (kIsWeb) return;
    if (_appId.isEmpty) return;

    try {
      if (!_initialized) {
        OneSignal.Debug.setLogLevel(OSLogLevel.none);
        OneSignal.Debug.setAlertLevel(OSLogLevel.none);
        OneSignal.initialize(_appId);
        await OneSignal.Notifications.requestPermission(true);
        _initialized = true;
      }
      OneSignal.login(uid);
    } catch (_) {
      // keep auth/session flow resilient if push setup is incomplete on device.
    }
  }

  static Future<void> onSignedOut() async {
    if (kIsWeb) return;
    if (!_initialized) return;
    try {
      OneSignal.logout();
    } catch (_) {
      // no-op
    }
  }
}
