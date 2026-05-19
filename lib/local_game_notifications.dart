import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalGameNotifications {
  static const MethodChannel _channel =
      MethodChannel('com.enzily.app/game_notifications');

  static int idFor(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash == 0 ? 9001 : hash;
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    DateTime? endAt,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('show', {
        'id': id,
        'title': title,
        'body': body,
        if (endAt != null) 'endAtMillis': endAt.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    if (kIsWeb) return;
    if (delay <= Duration.zero) return;
    try {
      await _channel.invokeMethod('schedule', {
        'id': id,
        'title': title,
        'body': body,
        'delaySeconds': delay.inSeconds,
      });
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('cancel', {'id': id});
    } catch (_) {}
  }
}
