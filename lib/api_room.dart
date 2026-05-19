// lib/api_room.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiRoom {
  static const Duration _timeout = Duration(seconds: 20);

  static Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _decodeJson(http.Response res) {
    try {
      final m = jsonDecode(res.body);
      if (m is Map<String, dynamic>) return m;
      throw Exception('Invalid JSON shape');
    } catch (e) {
      throw Exception('Invalid JSON response: $e');
    }
  }

  static Never _throwApiErr(
    Map<String, dynamic>? m,
    http.Response res,
    String fallback,
  ) {
    final msg = (m != null && m['message'] is String)
        ? m['message'] as String
        : fallback;
    throw Exception('$msg (HTTP ${res.statusCode})');
  }

  static Map<String, dynamic> _dataOrThrow(
    http.Response res, {
    String fallback = 'Request failed',
  }) {
    final m = _decodeJson(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      _throwApiErr(m, res, fallback);
    }
    final data = m['data'];
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  static String friendlyError(Object error) {
    final text = error.toString();
    final active =
        RegExp(r'PLAYER_ALREADY_IN_ACTIVE_ROOM:([A-Z0-9]+)').firstMatch(text);
    if (active != null) {
      return 'عندك قيم شغال حالياً (${active.group(1)}). خلّصه أو لغيه قبل لا تبلش قيم ثاني.';
    }
    if (text.contains('ROOM_NOT_JOINABLE')) {
      return 'القيم بدأ أو انتهى، ما تقدر تدخل عليه الحين.';
    }
    if (text.contains('ROOM_LOCKED')) {
      return 'القيم مقفل لين يخلص العدّاد.';
    }
    if (text.contains('ROOM_NOT_CANCELABLE')) {
      return 'ما نقدر نلغي هالقيم حالياً.';
    }
    if (text.contains('Cannot POST /api/rooms/') && text.contains('/cancel')) {
      return 'الإلغاء مو شغال لأن نسخة السيرفر الحالية ما فيها مسار إلغاء القيم. لازم تحديث الباكند.';
    }
    if (text.contains('Cannot DELETE /api/rooms/')) {
      return 'الإلغاء مو شغال لأن نسخة السيرفر الحالية قديمة. لازم تحديث الباكند.';
    }
    return text;
  }

  /// إنشاء روم (عادي أو مع سبونسر)
  static Future<Map<String, dynamic>> createRoom({
    required String gameId,
    String? sponsorCode,
    String? dewanyahId,
    required String? token,
    double? lat,
    double? lng,
    int? radiusMeters,
  }) async {
    final body = <String, dynamic>{
      'gameId': gameId,
      if (sponsorCode != null && sponsorCode.trim().isNotEmpty)
        'sponsorCode': sponsorCode.trim(),
      if (dewanyahId != null && dewanyahId.trim().isNotEmpty)
        'dewanyahId': dewanyahId.trim(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radiusMeters != null) 'radiusMeters': radiusMeters,
    };

    final res = await http
        .post(
          Uri.parse('$apiBase/rooms'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _dataOrThrow(res, fallback: 'Failed to create room');
  }

  /// الشّرف لروم بالكود (userId من التوكن)
  static Future<void> joinByCode({
    required String code,
    required String? token,
    double? lat,
    double? lng,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/join'),
          headers: _headers(token: token),
          body: jsonEncode({
            'code': code,
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          }),
        )
        .timeout(_timeout);

    final m = _decodeJson(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      _throwApiErr(m, res, 'Failed to join room');
    }
  }

  /// جلب روم بالكود
  static Future<Map<String, dynamic>> getRoomByCode(
    String code, {
    String? token,
  }) async {
    final res = await http
        .get(
          Uri.parse('$apiBase/rooms/$code'),
          headers: _headers(token: token),
        )
        .timeout(_timeout);

    return _dataOrThrow(res, fallback: 'Failed to fetch room');
  }

  /// بدء الروم (المضيف فقط)
  static Future<Map<String, dynamic>> startRoom({
    required String code,
    required String? token,
    int? timerSec,
    int? targetWinPoints,
    bool? allowZeroCredit,
  }) async {
    final body = <String, dynamic>{
      if (targetWinPoints != null) 'targetWinPoints': targetWinPoints,
      if (allowZeroCredit != null) 'allowZeroCredit': allowZeroCredit,
      if (timerSec != null) 'timerSec': timerSec,
    };

    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/$code/start'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _dataOrThrow(res, fallback: 'Failed to start room');
  }

  /// إلغاء الروم وإرجاع أي لآلئ محجوزة
  static Future<Map<String, dynamic>> cancelRoom({
    required String code,
    required String? token,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    Future<http.Response> postTo(String url, Map<String, dynamic> payload) {
      return http
          .post(
            Uri.parse(url),
            headers: _headers(token: token),
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    }

    Future<http.Response> deleteTo(String url) {
      return http
          .delete(
            Uri.parse(url),
            headers: _headers(token: token),
          )
          .timeout(_timeout);
    }

    final attempts = <Future<http.Response> Function()>[
      () => postTo('$apiBase/rooms/$code/cancel', body),
      () => postTo('$apiBase/rooms/cancel', {
            'code': code,
            ...body,
          }),
      () => deleteTo('$apiBase/rooms/$code'),
    ];

    Map<String, dynamic>? lastError;
    http.Response? lastResponse;

    for (var i = 0; i < attempts.length; i++) {
      final res = await attempts[i]();
      final parsed = _decodeJson(res);
      if (res.statusCode < 400 && parsed['ok'] == true) {
        final data = parsed['data'];
        return data is Map<String, dynamic> ? data : {'data': data};
      }

      lastError = parsed;
      lastResponse = res;
      final message = (parsed['message'] ?? '').toString();
      final notFound = res.statusCode == 404 ||
          message.contains('Cannot POST') ||
          message.contains('Cannot DELETE') ||
          message.contains('ROOM_NOT_FOUND');
      if (!notFound || i == attempts.length - 1) {
        break;
      }
    }

    _throwApiErr(lastError, lastResponse!, 'Failed to cancel room');
  }

  /// تعديل نقاط الرهان/اللعب قبل البدء
  static Future<Map<String, dynamic>> setStake({
    required String code,
    required int amount,
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/$code/stake'),
          headers: _headers(token: token),
          body: jsonEncode({'amount': amount}),
        )
        .timeout(_timeout);

    return _dataOrThrow(res, fallback: 'Failed to set stake');
  }

  /// تعيين فريق اللاعب (لو الباكند يدعم /rooms/:code/team)
  static Future<void> setPlayerTeam({
    required String code,
    required String playerUserId,
    required String team, // 'A' أو 'B'
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/$code/team'),
          headers: _headers(token: token),
          body: jsonEncode({
            'playerUserId': playerUserId,
            'team': team,
          }),
        )
        .timeout(_timeout);

    final m = _decodeJson(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      _throwApiErr(m, res, 'Failed to set team');
    }
  }

  /// تعيين قائد الفريق (لو الباكند يدعم /rooms/:code/leader)
  static Future<void> setTeamLeader({
    required String code,
    required String team, // 'A' أو 'B'
    required String leaderUserId,
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/$code/leader'),
          headers: _headers(token: token),
          body: jsonEncode({
            'team': team,
            'leaderUserId': leaderUserId,
          }),
        )
        .timeout(_timeout);

    final m = _decodeJson(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      _throwApiErr(m, res, 'Failed to set leader');
    }
  }

  /// حسم النتيجة (يرسله المضيف فقط) → تتحول الحالة إلى pending للموافقات
  static Future<Map<String, dynamic>> submitResult({
    required String code,
    required List<String> winners,
    required List<String> losers,
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/$code/result'),
          headers: _headers(token: token),
          body: jsonEncode({
            'winners': winners,
            'losers': losers,
          }),
        )
        .timeout(_timeout);
    return _dataOrThrow(res, fallback: 'Failed to submit result');
  }

  /// تصويت لاعب على النتيجة (موافقة/رفض)
  static Future<Map<String, dynamic>> voteResult({
    required String code,
    required bool approve,
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/rooms/$code/result/vote'),
          headers: _headers(token: token),
          body: jsonEncode({'approve': approve}),
        )
        .timeout(_timeout);
    return _dataOrThrow(res, fallback: 'Failed to vote on result');
  }

  /// حالة النتيجة والأصوات (للاستطلاع)
  static Future<Map<String, dynamic>> getState({
    required String code,
    required String? token,
  }) async {
    final res = await http
        .get(
          Uri.parse('$apiBase/rooms/$code/state'),
          headers: _headers(token: token),
        )
        .timeout(_timeout);
    return _dataOrThrow(res, fallback: 'Failed to fetch room state');
  }
}
