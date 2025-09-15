import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

Future<Map<String, dynamic>> createRoom({
  required String gameId,
  required String hostUserId,
}) async {
  final res = await http.post(
    Uri.parse('$apiBase/rooms?userId=$hostUserId'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'gameId': gameId}),
  );
  if (res.statusCode >= 400) {
    throw 'Create failed: ${res.statusCode} ${res.body}';
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}

Future<void> joinByCode({
  required String code,
  required String userId,
}) async {
  final res = await http.post(
    Uri.parse('$apiBase/rooms/join?userId=$userId'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'code': code}),
  );
  if (res.statusCode >= 400) {
    throw 'Join failed: ${res.statusCode} ${res.body}';
  }
}

Future<List<Map<String, dynamic>>> getPlayers(String roomId) async {
  final res = await http.get(Uri.parse('$apiBase/rooms/$roomId/players'));
  if (res.statusCode >= 400) throw res.body;
  final list = jsonDecode(res.body) as List;
  return list.cast<Map<String, dynamic>>();
}
