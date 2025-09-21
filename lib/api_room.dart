import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiRoom {
  static Future<Map<String, dynamic>> createRoom({
    required String gameId,
    required String hostUserId,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms'),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: jsonEncode({'gameId': gameId, 'hostId': hostUserId}),
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) throw 'Create failed: ${res.statusCode} ${res.body}';
    return m['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> joinByCode({
    required String code,
    required String userId,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/join'),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: jsonEncode({'code': code, 'userId': userId}),
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) throw 'Join failed: ${res.statusCode} ${res.body}';
    return m['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRoomByCode(String code, {String? token}) async {
    final res = await http.get(
      Uri.parse('$apiBase/rooms/$code'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) throw 'Fetch failed: ${res.statusCode} ${res.body}';
    return m['data'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getPlayers(String code, {String? token}) async {
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
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/$code/start'),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        if (targetWinPoints != null) 'targetWinPoints': targetWinPoints,
        if (allowZeroCredit != null) 'allowZeroCredit': allowZeroCredit,
      }),
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) throw 'Start failed: ${res.statusCode} ${res.body}';
    return m['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> setStake({
    required String code,
    required int amount,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/rooms/$code/stake'),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: jsonEncode({'amount': amount}),
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) throw 'Stake failed: ${res.statusCode} ${res.body}';
    return m['data'] as Map<String, dynamic>;
  }
}
