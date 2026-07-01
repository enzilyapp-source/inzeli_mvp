import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalBridge {
  static const String _appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'ca700a2c-c00e-4f0d-9fbb-e56e7d6854ea',
  );
  static bool _initialized = false;
  static bool _permissionRequested = false;

  static bool get isSupported => !kIsWeb && _appId.isNotEmpty;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!isSupported) return;
    if (_initialized) return;

    try {
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.verbose : OSLogLevel.none,
      );
      OneSignal.Debug.setAlertLevel(OSLogLevel.none);
      OneSignal.initialize(_appId);
      OneSignal.User.pushSubscription.addObserver((state) {
        if (kDebugMode) {
          debugPrint(
            'OneSignal push subscription: id=${state.current.id}, optedIn=${state.current.optedIn}',
          );
        }
      });
      OneSignal.Notifications.addClickListener((event) {
        if (kDebugMode) {
          debugPrint(
            'OneSignal notification opened: ${event.notification.notificationId}',
          );
        }
      });
      _initialized = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OneSignal init failed: $error');
      }
    }
  }

  static Future<void> requestPermission() async {
    if (!isSupported) return;
    if (_permissionRequested) return;

    await initialize();
    if (!_initialized) return;

    try {
      await OneSignal.Notifications.requestPermission(true);
      OneSignal.User.pushSubscription.optIn();
      _permissionRequested = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OneSignal permission failed: $error');
      }
    }
  }

  static Future<void> syncSignedInUser(String? userId) async {
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) return;
    if (!isSupported) return;

    try {
      await initialize();
      if (!_initialized) return;
      OneSignal.login(uid);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OneSignal login failed: $error');
      }
    }
  }

  static Future<void> onSignedOut() async {
    if (!isSupported) return;
    await initialize();
    if (!_initialized) return;
    try {
      OneSignal.logout();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OneSignal logout failed: $error');
      }
    }
  }
}
