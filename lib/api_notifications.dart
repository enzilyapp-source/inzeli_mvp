import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiNotifications {
  static Future<List<Map<String, dynamic>>> list({
    required String token,
    int limit = 50,
    DateTime? since,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if (since != null) 'since': since.toIso8601String(),
    };
    final uri =
        Uri.parse('$apiBase/notifications').replace(queryParameters: query);
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final raw = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(raw);
    if (res.statusCode >= 400 || decoded is! Map || decoded['ok'] != true) {
      throw 'notifications fetch failed';
    }
    final data = decoded['data'];
    if (data is! List) return const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
