// lib/api_matches.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiMatches {
  /// Create a match result.
  ///
  /// - [roomCode] optional (for rooms with timers / locking)
  /// - [gameId] required game key (e.g. "CHESS", "TREX")
  /// - [winners] list of winner userIds
  /// - [losers] list of loser userIds
  /// - [stakeUnits] 1, 2, or 3 (clamped automatically)
  /// - [sponsorCode] optional sponsor for sponsor-only matches
  /// - [token] required JWT
  ///
  /// Returns created match as Map<String, dynamic>.
  static Future<Map<String, dynamic>> createMatch({
    String? roomCode,
    required String gameId,
    required List<String> winners,
    required List<String> losers,
    int stakeUnits = 1,
    String? sponsorCode,
    String? token,
  }) async {
    final int units = stakeUnits.clamp(1, 3);

    final uri = Uri.parse('$apiBase/matches');
    final body = <String, dynamic>{
      'gameId': gameId,
      'winners': winners,
      'losers': losers,
      'stakeUnits': units,
      if (roomCode != null && roomCode.isNotEmpty) 'roomCode': roomCode,
      if (sponsorCode != null && sponsorCode.trim().isNotEmpty)
        'sponsorCode': sponsorCode.trim(),
    };

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic> m;
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Match failed: ${res.statusCode} — Bad server response';
    }

    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = (m['message'] ?? 'Match failed').toString();
      final code = (m['code'] ?? '').toString();
      throw code.isNotEmpty ? '$msg ($code)' : msg;
    }

    final data = m['data'];
    if (data is! Map<String, dynamic>) {
      throw 'Match failed: invalid data payload';
    }
    return data;
  }

  /// Shortcut for a simple 1v1 duel match.
  ///
  /// - winnerId: ID of the winner
  /// - loserId: ID of the loser
  /// - sponsorCode: optional; pass for sponsor match
  static Future<Map<String, dynamic>> createDuel({
    String? roomCode,
    required String gameId,
    required String winnerId,
    required String loserId,
    int stakeUnits = 1,
    String? sponsorCode,
    String? token,
  }) {
    return createMatch(
      roomCode: roomCode,
      gameId: gameId,
      winners: [winnerId],
      losers: [loserId],
      stakeUnits: stakeUnits,
      sponsorCode: sponsorCode,
      token: token,
    );
  }

  /// Fetch all matches of a given user (optional: by sponsor).
  static Future<List<Map<String, dynamic>>> listUserMatches({
    required String userId,
    String? sponsorCode,
    String? token,
  }) async {
    final params = <String, String>{
      'userId': userId,
      if (sponsorCode != null && sponsorCode.isNotEmpty)
        'sponsorCode': sponsorCode,
    };

    final uri = Uri.parse('$apiBase/matches/user').replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode >= 400) {
      throw 'Failed to fetch matches (${res.statusCode})';
    }

    final m = jsonDecode(res.body);
    if (m is! Map || m['ok'] != true) {
      throw 'Failed to fetch matches';
    }

    final data = m['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }
}
//lib/api_matches.dart