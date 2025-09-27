import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

Future<Map<String, dynamic>?> getUserStats(String userId, {String? token, String? gameId}) async {
  final uri = Uri.parse('$apiBase/users/$userId/stats${gameId != null ? '?gameId=$gameId' : ''}');
  final res = await http.get(uri, headers: {
    if (token != null) 'Authorization': 'Bearer $token',
  });
  try {
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (m['ok'] == true) return m['data'] as Map<String, dynamic>;
    return null;
  } catch (_) {
    return null;
  }
}
//api_user.dart