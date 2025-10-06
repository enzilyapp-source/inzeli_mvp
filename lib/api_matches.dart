// lib/api_matches.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiMatches {
  /// Create a match result.
  ///
  /// - [roomCode] optional (for rooms with timers / locking)
  /// - [gameId] the game key (e.g. "بلياردو", "TREX")
  /// - [winners] list of winner userIds
  /// - [losers]  list of loser userIds
  /// - [stakeUnits] must be 1, 2 or 3 (will be clamped to 1..3)
  /// - [token] JWT from sign in (Authorization: Bearer <token>)
  static Future<Map<String, dynamic>> createMatch({
    String? roomCode,
    required String gameId,
    required List<String> winners,
    required List<String> losers,
    int stakeUnits = 1,
    String? token,
  }) async {
    // clamp stakeUnits to 1..3 just to be safe client-side
    final int units = stakeUnits.clamp(1, 3);

    final uri = Uri.parse('$apiBase/matches');
    final body = <String, dynamic>{
      'gameId': gameId,
      'winners': winners,
      'losers': losers,
      'stakeUnits': units,
      if (roomCode != null && roomCode.isNotEmpty) 'roomCode': roomCode,
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
      // surface backend error message/code if present
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

  /// Convenience for 1v1 (duel): you pass winner, loser and units.
  static Future<Map<String, dynamic>> createDuel({
    String? roomCode,
    required String gameId,
    required String winnerId,
    required String loserId,
    int stakeUnits = 1,
    String? token,
  }) {
    return createMatch(
      roomCode: roomCode,
      gameId: gameId,
      winners: [winnerId],
      losers: [loserId],
      stakeUnits: stakeUnits,
      token: token,
    );
  }
}
//api_matches.dart