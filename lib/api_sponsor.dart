// lib/api_sponsor.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiSponsors {
  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  /// GET /sponsors
  static Future<List<Map<String, dynamic>>> listSponsors() async {
    final uri = Uri.parse('$apiBase/sponsors');
    final res = await http.get(uri);
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw 'Failed to load sponsors';
    }
    final data = m['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  /// GET /sponsors/:code  → { sponsor, games }
  static Future<Map<String, dynamic>> getSponsorDetail({
    required String code,
    String? token,
  }) async {
    final uri = Uri.parse('$apiBase/sponsors/$code');
    final res = await http.get(uri, headers: _headers(token: token));
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw (m is Map ? (m['message'] ?? 'Failed') : 'Failed').toString();
    }
    return (m['data'] as Map).cast<String, dynamic>();
  }

  /// GET /sponsors/:code/wallets/me
  static Future<List<Map<String, dynamic>>> getMyWallets({
    required String sponsorCode,
    required String token,
  }) async {
    final uri = Uri.parse('$apiBase/sponsors/$sponsorCode/wallets/me');
    final res = await http.get(uri, headers: _headers(token: token));
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw 'Failed to load wallets';
    }
    final data = m['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  /// POST /sponsors/:code/join
  static Future<void> joinSponsor({
    required String sponsorCode,
    required String token,
  }) async {
    final uri = Uri.parse('$apiBase/sponsors/$sponsorCode/join');
    final res = await http.post(uri, headers: _headers(token: token));
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw (m is Map ? (m['message'] ?? 'Failed') : 'Failed').toString();
    }
  }

  /// GET /sponsors/:code/leaderboard?gameId=...
  /// backend يرجّع { sponsor, gameId, rows: [...] }
  static Future<Map<String, dynamic>> getSponsorLeaderboard({
    required String sponsorCode,
    required String gameId,
  }) async {
    final uri = Uri.parse('$apiBase/sponsors/$sponsorCode/leaderboard')
        .replace(queryParameters: {'gameId': gameId});
    final res = await http.get(uri);
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw 'Failed to load sponsor leaderboard';
    }
    final data = m['data'];
    return (data as Map).cast<String, dynamic>();
  }
}
