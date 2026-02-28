import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiUsers {
  /// Fetch multiple users by ids (if backend supports it), otherwise returns [].
  static Future<List<Map<String, dynamic>>> getMany({required List<String> ids, String? token}) async {
    if (ids.isEmpty) return const [];
    // Try batch endpoint: /users?ids=id1,id2
    final uri = Uri.parse('$apiBase/users?ids=${ids.join(',')}');
    final res = await http.get(uri, headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });
    if (res.statusCode >= 400) return const [];
    final body = jsonDecode(res.body);
    if (body is Map && body['data'] is List) {
      return (body['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (body is List) {
      return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }
}
