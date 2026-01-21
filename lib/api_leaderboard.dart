// lib/api_leaderboard.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiLeaderboard {
  static Future<List<Map<String, dynamic>>> globalTop({String? token, int limit = 20}) async {
    final uri = Uri.parse('$apiBase/leaderboard/global?limit=$limit');
    final res = await http.get(uri, headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw 'global leaderboard failed';
    }
    final data = m['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> sponsorGameTop({
    required String sponsorCode,
    required String gameId,
    String? token,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$apiBase/leaderboard/sponsor?sponsorCode=$sponsorCode&gameId=$gameId&limit=$limit');
    final res = await http.get(uri, headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw 'sponsor leaderboard failed';
    }
    final data = m['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }
}
