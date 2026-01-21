// lib/api_matches.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiMatches {
  static const Duration _timeout = Duration(seconds: 20);

  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Map<String, dynamic> _decodeJson(http.Response res) {
    try {
      final body = res.body.isEmpty ? '{}' : res.body;
      final m = jsonDecode(body);
      if (m is Map<String, dynamic>) return m;
      return {'raw': m};
    } catch (e) {
      return {'raw': res.body};
    }
  }

  static Never _throwApiErr(
      Map<String, dynamic> m,
      http.Response res,
      String fallback,
      ) {
    final msg = (m['message'] ?? fallback).toString();
    throw Exception('$msg (status: ${res.statusCode})');
  }

  /// تسجيل مباراة جديدة
  static Future<Map<String, dynamic>> createMatch({
    String? roomCode,
    required String gameId,
    required List<String> winners,
    required List<String> losers,
    String? sponsorCode,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'gameId': gameId,
      'winners': winners,
      'losers': losers,
      if (roomCode != null) 'roomCode': roomCode,
      if (sponsorCode != null) 'sponsorCode': sponsorCode,
    };

    final uri = Uri.parse('$apiBase/matches');
    late http.Response res;
    try {
      res = await http
          .post(
        uri,
        headers: _headers(token: token),
        body: jsonEncode(body),
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw 'Timeout while creating match';
    } catch (e) {
      throw 'Network error: $e';
    }

    final m = _decodeJson(res);

    if (res.statusCode >= 400 || m['ok'] != true) {
      _throwApiErr(m, res, 'Match failed');
    }

    final data = m['data'];
    if (data is Map<String, dynamic>) return data;
    return (data as Map).cast<String, dynamic>();
  }

  /// (اختياري) جلب مباريات المستخدم/الروم لو حبيتي تبنين تايملاين
  static Future<List<Map<String, dynamic>>> listMatchesForRoom({
    required String roomCode,
    String? token,
  }) async {
    final uri = Uri.parse('$apiBase/matches?roomCode=$roomCode');
    late http.Response res;
    try {
      res = await http
          .get(
        uri,
        headers: _headers(token: token),
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw 'Timeout while fetching matches';
    } catch (e) {
      throw 'Failed to fetch matches: $e';
    }

    final m = _decodeJson(res);

    if (res.statusCode >= 400 || m['ok'] != true) {
      _throwApiErr(m, res, 'Failed to fetch matches');
    }

    final data = m['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }
}
