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

  /// إنشاء روم (عادي أو مع سبونسر)
  static Future<Map<String, dynamic>> createRoom({
    required String gameId,
    String? sponsorCode,
    required String? token,
  }) async {
    final body = <String, dynamic>{
      'gameId': gameId,
      if (sponsorCode != null && sponsorCode.trim().isNotEmpty)
        'sponsorCode': sponsorCode.trim(),
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

  /// الانضمام لروم بالكود (userId من التوكن)
  static Future<void> joinByCode({
    required String code,
    required String? token,
  }) async {
    final res = await http
        .post(
      Uri.parse('$apiBase/rooms/join'),
      headers: _headers(token: token),
      body: jsonEncode({'code': code}),
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
}
