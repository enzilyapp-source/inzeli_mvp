import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

Future<Map<String, dynamic>> createRoom({
  required String gameId,
  required String hostUserId,
}) async {
  final uri = Uri.parse('$apiBase/rooms?userId=$hostUserId');
  final body = jsonEncode({'gameId': gameId});
  try {
    final res = await http.post(uri, headers: {'Content-Type':'application/json'}, body: body);
    // 🔎 اطبع كل شيء للتشخيص
    // ignore: avoid_print
    print('[CREATE ROOM] ${res.statusCode} ${res.reasonPhrase}\nURL: $uri\nBODY: $body\nRES: ${res.body}');
    if (res.statusCode >= 400) {
      throw 'Create failed ${res.statusCode}: ${res.body}';
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  } catch (e) {
    // ignore: avoid_print
    print('[CREATE ROOM ERROR] $e');
    rethrow;
  }
}


Future<List<Map<String, dynamic>>> getPlayers(String roomId) async {
  final res = await http.get(Uri.parse('$apiBase/rooms/$roomId/players'));
  if (res.statusCode >= 400) throw res.body;
  final list = jsonDecode(res.body) as List;
  return list.cast<Map<String, dynamic>>();
}

Future<void> joinByCode({required String code, required String userId}) async {
  final uri = Uri.parse('$apiBase/rooms/join?userId=$userId');
  final body = jsonEncode({'code': code});
  final res = await http.post(uri, headers: {'Content-Type':'application/json'}, body: body);
  // ignore: avoid_print
  print('[JOIN] ${res.statusCode} ${res.reasonPhrase}\nURL: $uri\nBODY: $body\nRES: ${res.body}');
  if (res.statusCode >= 400) {
    throw 'Join failed ${res.statusCode}: ${res.body}';
  }

}
