import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiRoom {
  /// Create a room.
  /// Works with backends that rely on JWT (token) OR require explicit host id.
  static Future<Map<String, dynamic>> createRoom({
    required String gameId,
    String? hostUserId,
    String? token,
  }) async {
    // safer JSON body
    final body = jsonEncode({
      'gameId': gameId,
      if (hostUserId != null && hostUserId.isNotEmpty) 'hostId': hostUserId,
    });

    final res = await http.post(
      Uri.parse('$apiBase/rooms'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: body,
    );

    // 🪲 print debug info to see what backend says
    print('🔍 CreateRoom status: ${res.statusCode}');
    print('🔍 Body sent: $body');
    print('🔍 Response: ${res.body}');

    Map<String, dynamic> m = {};
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Create failed (${res.statusCode}): invalid JSON response ${res.body}';
    }

    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = (m['error'] ?? m['message'] ?? res.body).toString();
      throw 'Create failed (${res.statusCode}): $msg';
    }

    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }

  /// Join a room by code.
  /// Works with backends that rely on JWT or expect explicit userId.
  static Future<Map<String, dynamic>> joinByCode({
    required String code,
    String? userId, // optional
    String? token,
  }) async {
    final body = <String, dynamic>{'code': code};
    if (userId != null && userId.isNotEmpty) {
      body['userId'] = userId;
    }

    final res = await http.post(
      Uri.parse('$apiBase/rooms/join'),
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
      throw 'Join failed: ${res.statusCode} ${res.body}';
    }
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Join failed: ${res.statusCode} ${res.body}';
    }
    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRoomByCode(
      String code, {
        String? token,
      }) async {
    final res = await http.get(
      Uri.parse('$apiBase/rooms/$code'),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    Map<String, dynamic> m;
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Fetch failed: ${res.statusCode} ${res.body}';
    }
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Fetch failed: ${res.statusCode} ${res.body}';
    }
    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getPlayers(
      String code, {
        String? token,
      }) async {
    final room = await getRoomByCode(code, token: token);
    final players = room['players'];
    if (players is! List) return <Map<String, dynamic>>[];
    return players.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> startRoom({
    required String code,
    String? token,
    int? targetWinPoints,
    bool? allowZeroCredit,
    int? timerSec,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/$code/start'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (targetWinPoints != null) 'targetWinPoints': targetWinPoints,
        if (allowZeroCredit != null) 'allowZeroCredit': allowZeroCredit,
        if (timerSec != null) 'timerSec': timerSec,
      }),
    );

    Map<String, dynamic> m;
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Start failed: ${res.statusCode} ${res.body}';
    }
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Start failed: ${res.statusCode} ${res.body}';
    }
    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> setStake({
    required String code,
    required int amount,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/$code/stake'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );

    Map<String, dynamic> m;
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Set points failed: ${res.statusCode} ${res.body}';
    }
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Set points failed: ${res.statusCode} ${res.body}';
    }
    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> setPlayerTeam({
    required String code,
    required String playerUserId,
    required String team, // 'A' or 'B'
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/$code/team'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'playerUserId': playerUserId, 'team': team}),
    );

    Map<String, dynamic> m;
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Team set failed: ${res.statusCode} ${res.body}';
    }
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Team set failed: ${res.statusCode} ${res.body}';
    }
    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> setTeamLeader({
    required String code,
    required String team, // 'A' or 'B'
    required String leaderUserId,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/$code/team-leader'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'team': team, 'leaderUserId': leaderUserId}),
    );

    Map<String, dynamic> m;
    try {
      m = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw 'Leader set failed: ${res.statusCode} ${res.body}';
    }
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw 'Leader set failed: ${res.statusCode} ${res.body}';
    }
    return (m['data'] ?? const {}) as Map<String, dynamic>;
  }
}
