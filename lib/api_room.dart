import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

T _parseData<T>(http.Response res) {
  final body = jsonDecode(res.body);
  if (body is Map<String, dynamic> && body.containsKey('ok')) {
    if (body['ok'] != true) {
      final msg = (body['message'] ?? 'Request failed').toString();
      final code = body['code']?.toString();
      throw 'Server error${code != null ? " ($code)" : ""}: $msg';
    }
    return (body['data'] as Map<String, dynamic>) as T;
  }
  return body as T;
}

Future<Map<String, dynamic>> createRoom({
  required String gameId, required String hostUserId, String? token,
}) async {
  final res = await http.post(
    Uri.parse('$apiBase/rooms'),
    headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
    body: jsonEncode({'gameId': gameId, 'hostId': hostUserId}),
  );
  if (res.statusCode >= 400) { throw 'Create failed: ${res.statusCode} ${res.body}'; }
  return _parseData<Map<String, dynamic>>(res);
}

Future<Map<String, dynamic>> joinByCode({
  required String code, required String userId, String? token,
}) async {
  final res = await http.post(
    Uri.parse('$apiBase/rooms/join'),
    headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
    body: jsonEncode({'code': code, 'userId': userId}),
  );
  if (res.statusCode >= 400) { throw 'Join failed: ${res.statusCode} ${res.body}'; }
  return _parseData<Map<String, dynamic>>(res);
}

Future<Map<String, dynamic>> getRoomByCode(String code, {String? token}) async {
  final res = await http.get(
    Uri.parse('$apiBase/rooms/$code'),
    headers: { if (token != null) 'Authorization': 'Bearer $token' },
  );
  if (res.statusCode >= 400) { throw 'Fetch failed: ${res.statusCode} ${res.body}'; }
  return _parseData<Map<String, dynamic>>(res);
}

Future<List<Map<String, dynamic>>> getPlayers(String code, {String? token}) async {
  final room = await getRoomByCode(code, token: token);
  final players = room['players'];
  if (players is! List) return <Map<String, dynamic>>[];
  return players.cast<Map<String, dynamic>>();
}
