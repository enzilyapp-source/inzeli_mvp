// lib/api_timeline.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiTimeline {
  static Future<List<Map<String, dynamic>>> list({
    String? token,
    int limit = 100,
    String? gameId,
    bool global = true,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (gameId != null && gameId.isNotEmpty) 'gameId': gameId,
      if (global) 'scope': 'all',
    };
    final uri =
        Uri.parse('$apiBase/timeline').replace(queryParameters: query);
    final res = await http.get(uri, headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m is! Map || m['ok'] != true) {
      throw 'timeline fetch failed';
    }
    final data = m['data'];
    if (data is! List) return const [];
    return data.cast<Map<String, dynamic>>();
  }
}
