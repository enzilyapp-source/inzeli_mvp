// lib/api_sponsor.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiSponsors {
  /// GET /api/sponsors
  static Future<List<Map<String, dynamic>>> listSponsors() async {
    final res = await http.get(Uri.parse('$apiBase/sponsors'));
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Failed to list sponsors: ${res.statusCode} ${res.body}';
    }
    final data = m['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return <Map<String, dynamic>>[];
  }

  /// GET /api/sponsors/:code
  /// Returns: { sponsor: {...}, games: [...] }
  static Future<Map<String, dynamic>> getSponsorDetail({
    required String code,
    String? token,
  }) async {
    final res = await http.get(
      Uri.parse('$apiBase/sponsors/$code'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Failed to get sponsor: ${res.statusCode} ${res.body}';
    }

    final data = (m['data'] ?? const {}) as Map<String, dynamic>;

    // convenience: flatten some fields
    if (!data.containsKey('name') && data['sponsor'] is Map) {
      final s = data['sponsor'] as Map;
      data['name'] = s['name'];
      data['code'] = s['code'];
    }

    // ensure each game row has gameId / gameName
    if (data['games'] is List) {
      data['games'] = (data['games'] as List).map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        final game = (row['game'] as Map?) ?? const {};
        row['gameId'] ??= game['id'];
        row['gameName'] ??= game['name'];
        return row;
      }).toList();
    }

    return data;
  }

  /// POST /api/sponsors/:code/join
  static Future<void> joinSponsor({
    required String sponsorCode,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/sponsors/$sponsorCode/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Failed to join sponsor: ${res.statusCode} ${res.body}';
    }
  }

  /// GET /api/sponsors/:code/wallets/me
  /// Returns: [{ userId, sponsorCode, gameId, pearls, game: {...} }]
  static Future<List<Map<String, dynamic>>> getMyWallets({
    required String sponsorCode,
    required String token, // <-- non-nullable & required
  }) async {
    final res = await http.get(
      Uri.parse('$apiBase/sponsors/$sponsorCode/wallets/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Failed to load wallets: ${res.statusCode} ${res.body}';
    }
    final data = m['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return <Map<String, dynamic>>[];
  }
}
