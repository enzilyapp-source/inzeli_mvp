import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiResponse<T> {
  final bool ok; final String message; final T? data; final String? code;
  ApiResponse({required this.ok, required this.message, this.data, this.code});
  static ApiResponse<Map<String, dynamic>> fromHttp(http.Response res) {
    try {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResponse(
        ok: m['ok'] == true,
        message: (m['message'] ?? 'No message') as String,
        data: m['data'] as Map<String, dynamic>?,
        code: m['code'] as String?,
      );
    } catch (_) {
      return ApiResponse(ok: false, message: 'Bad server response (${res.statusCode})');
    }
  }
}

Future<ApiResponse<Map<String, dynamic>>> _post(String path, Map<String, dynamic> body) async {
  final res = await http.post(
    Uri.parse('$apiBase$path'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  // debug print
  // ignore: avoid_print
  print('AUTH $path → ${res.statusCode} ${res.body}');
  return ApiResponse.fromHttp(res);
}

Future<ApiResponse<Map<String, dynamic>>> register({
  required String email, required String password, required String displayName,
}) => _post('/auth/register', {'email': email, 'password': password, 'displayName': displayName});

Future<ApiResponse<Map<String, dynamic>>> login({
  required String email, required String password,
}) => _post('/auth/login', {'email': email, 'password': password});


//api_auth.dart