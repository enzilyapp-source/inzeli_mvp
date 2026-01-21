import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = String.fromEnvironment(
  'API_BASE',
  defaultValue:
      'https://inzeli-api-6heq.onrender.com/api', // override locally with --dart-define=API_BASE=http://10.0.2.2:3000/api
);

class ApiResponse<T> {
  final bool ok;
  final String message;
  final T? data;
  final String? code; // server error code like ROOM_NOT_FOUND

  ApiResponse({required this.ok, required this.message, this.data, this.code});

  static ApiResponse<Map<String, dynamic>> fromHttp(http.Response res) {
    try {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResponse<Map<String, dynamic>>(
        ok: m['ok'] == true,
        message: (m['message'] ?? 'No message') as String,
        data: m['data'] is Map<String, dynamic> ? (m['data'] as Map<String, dynamic>) : null,
        code: m['code'] as String?,
      );
    } catch (_) {
      return ApiResponse(ok: false, message: 'Bad server response (${res.statusCode})');
    }
  }
}

Future<ApiResponse<Map<String, dynamic>>> postJson(
    String path,
    Map<String, dynamic> body, {
      String? token,
    }) async {
  final res = await http.post(
    Uri.parse('$baseUrl$path'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  return ApiResponse.fromHttp(res);
}

Future<ApiResponse<Map<String, dynamic>>> getJson(
    String path, {
      String? token,
    }) async {
  final res = await http.get(
    Uri.parse('$baseUrl$path'),
    headers: { if (token != null) 'Authorization': 'Bearer $token' },
  );
  return ApiResponse.fromHttp(res);
}
//lib/api_core.dart
