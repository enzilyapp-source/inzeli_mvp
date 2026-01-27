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

Future<List<Map<String, dynamic>>> searchUsers(String query, {String? token}) async {
  final uri = Uri.parse('$apiBase/users/search/${Uri.encodeComponent(query)}');
  final res = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  });
  final body = res.body.isEmpty ? '{}' : res.body;
  final m = jsonDecode(body);
  if (res.statusCode >= 400 || m is! Map || m['ok'] != true) return const [];
  final data = m['data'];
  if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return const [];
}

Future<Map<String, dynamic>> deleteAccount({required String token}) async {
  final uri = Uri.parse('$apiBase/users/me');
  final res = await http.delete(uri, headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  });
  final body = res.body.isEmpty ? '{}' : res.body;
  try {
    final m = jsonDecode(body) as Map<String, dynamic>;
    return {
      'ok': m['ok'] == true,
      'message': (m['message'] ?? 'No message').toString(),
    };
  } catch (_) {
    return {'ok': false, 'message': 'Bad server response (${res.statusCode})'};
  }
}
//api_user.dart
