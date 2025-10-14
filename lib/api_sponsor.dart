// lib/api_sponsor.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiSponsors {
  // GET /api/sponsors
  static Future<List<Map<String, dynamic>>> listSponsors() async {
    final res = await http.get(Uri.parse('$apiBase/sponsors'));
    final m = _json(res);
    _assertOk(res, m, 'Load sponsors failed');
    final data = m['data'];
    if (data is! List) return <Map<String, dynamic>>[];
    return data.cast<Map<String, dynamic>>();
  }

  // GET /api/sponsors/:code
  static Future<Map<String, dynamic>> getSponsor(String code) async {
    final res = await http.get(Uri.parse('$apiBase/sponsors/$code'));
    final m = _json(res);
    _assertOk(res, m, 'Load sponsor failed');
    final data = m['data'];
    if (data is! Map<String, dynamic>) return <String, dynamic>{};
    return data;
  }

  // POST /api/sponsors/:code/join
  static Future<void> joinSponsor(String code, String token) async {
    final res = await http.post(
      Uri.parse('$apiBase/sponsors/$code/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final m = _json(res);
    _assertOk(res, m, 'Join sponsor failed');
  }

  // GET /api/sponsors/:code/wallets/me
  static Future<List<Map<String, dynamic>>> myWallets(
      String code, String token) async {
    final res = await http.get(
      Uri.parse('$apiBase/sponsors/$code/wallets/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final m = _json(res);
    _assertOk(res, m, 'Load wallets failed');
    final data = m['data'];
    if (data is! List) return <Map<String, dynamic>>[];
    return data.cast<Map<String, dynamic>>();
  }

  // POST /api/sponsors/:code/wallets/ensure  { gameId }
  // ensures the user has a wallet (creates with 5 pearls if missing)
  static Future<Map<String, dynamic>> getOrCreateWallet({
    required String token,
    required String sponsorCode,
    required String? gameId,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/sponsors/$sponsorCode/wallets/ensure'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'gameId': gameId}),
    );
    final m = _json(res);
    _assertOk(res, m, 'Ensure wallet failed');
    final data = m['data'];
    if (data is! Map<String, dynamic>) return <String, dynamic>{};
    return data;
  }

  // GET /api/sponsors/:code/leaderboard?gameId=CHESS
  static Future<List<Map<String, dynamic>>> leaderboard({
    required String sponsorCode,
    required String gameId,
  }) async {
    final uri = Uri.parse(
        '$apiBase/sponsors/$sponsorCode/leaderboard?gameId=$gameId');
    final res = await http.get(uri);
    final m = _json(res);
    _assertOk(res, m, 'Load leaderboard failed');
    final data = m['data'];
    if (data is! List) return <Map<String, dynamic>>[];
    return data.cast<Map<String, dynamic>>();
  }

  // --- helpers ---
  static Map<String, dynamic> _json(http.Response r) {
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'message': 'Bad server response', 'raw': r.body};
    }
  }

  static void _assertOk(http.Response r, Map<String, dynamic> m, String fallback) {
    if (r.statusCode >= 400 || m['ok'] != true) {
      final msg = (m['message'] ?? fallback).toString();
      final code = (m['code'] ?? '').toString();
      throw code.isNotEmpty ? '$msg ($code)' : msg;
    }
  }
}
