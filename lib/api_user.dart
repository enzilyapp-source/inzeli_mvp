import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

Future<({Map<String, dynamic>? data, int statusCode})> getMyProfile({
  required String token,
}) async {
  final uri = Uri.parse('$apiBase/users/me');
  final res = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  final body = res.body.isEmpty ? '{}' : res.body;
  try {
    final m = jsonDecode(body);
    if (m is Map && m['ok'] == true && m['data'] is Map) {
      return (
        data: Map<String, dynamic>.from(m['data'] as Map),
        statusCode: res.statusCode,
      );
    }
  } catch (_) {
    // ignore parse failures and fall back to null data
  }
  return (data: null, statusCode: res.statusCode);
}

Future<Map<String, dynamic>?> getUserStats(String userId,
    {String? token, String? gameId}) async {
  final uri = Uri.parse(
      '$apiBase/users/$userId/stats${gameId != null ? '?gameId=$gameId' : ''}');
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

Future<List<Map<String, dynamic>>> searchUsers(String query,
    {String? token}) async {
  final uri = Uri.parse('$apiBase/users/search/${Uri.encodeComponent(query)}');
  final res = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  });
  final body = res.body.isEmpty ? '{}' : res.body;
  final m = jsonDecode(body);
  if (res.statusCode >= 400 || m is! Map || m['ok'] != true) return const [];
  final data = m['data'];
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return const [];
}

Future<Map<String, dynamic>?> updateMyProfile({
  required String token,
  String? displayName,
  String? avatarBase64,
  String? avatarPath,
  String? themeId,
  String? frameId,
  String? cardId,
}) async {
  final uri = Uri.parse('$apiBase/users/me');
  final body = <String, dynamic>{};
  if (displayName != null) body['displayName'] = displayName;
  if (avatarBase64 != null) body['avatarBase64'] = avatarBase64;
  if (avatarPath != null) body['avatarPath'] = avatarPath;
  if (themeId != null) body['themeId'] = themeId;
  if (frameId != null) body['frameId'] = frameId;
  if (cardId != null) body['cardId'] = cardId;
  if (body.isEmpty) return null;

  final res = await http.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  final raw = res.body.isEmpty ? '{}' : res.body;
  try {
    final m = jsonDecode(raw);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) return null;
    final data = m['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  } catch (_) {
    return null;
  }
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
