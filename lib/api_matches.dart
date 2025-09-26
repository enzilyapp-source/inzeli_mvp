import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiMatches {
  static Future<Map<String, dynamic>> createMatch({
    String? roomCode,
    required String gameId,
    required List<String> winners,
    required List<String> losers,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBase/matches'),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        if (roomCode != null) 'roomCode': roomCode,
        'gameId': gameId,
        'winners': winners,
        'losers': losers,
      }),
    );
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || m['ok'] != true) throw 'Match failed: ${res.statusCode} ${res.body}';
    return m['data'] as Map<String, dynamic>;
  }
}
