import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';
import 'username_rules.dart';

String usernameErrorMessage(String code) => switch (code) {
      'USERNAME_TAKEN' => 'اسم المستخدم محجوز، اختَر اسمًا آخر',
      'USERNAME_RESERVED' => 'هذا الاسم مخصص للتطبيق، اختَر اسمًا آخر',
      'USERNAME_REQUIRED' => 'اسم المستخدم مطلوب',
      'USERNAME_INVALID' =>
        'استخدم ٣–٢٠ حرفًا يبدأ بحرف إنجليزي، مع أرقام أو _',
      'SERVER_UPDATE_REQUIRED' =>
        'حجز اسم المستخدم يحتاج تحديث الخادم. حسابك ونتائجك محفوظة.',
      _ => 'تعذر حفظ اسم المستخدم، حاول مرة أخرى',
    };

class UsernameException implements Exception {
  final String code;
  const UsernameException(this.code);
  @override
  String toString() => usernameErrorMessage(code);
}

class ApiUsernames {
  static Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 404) {
      throw const UsernameException('SERVER_UPDATE_REQUIRED');
    }
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400 || body is! Map || body['ok'] != true) {
      throw UsernameException(body is Map
          ? (body['code'] ?? 'USERNAME_SAVE_FAILED').toString()
          : 'USERNAME_SAVE_FAILED');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  static Future<Map<String, dynamic>> availability(String value,
      {http.Client? client}) async {
    final username = normalizedUsername(value);
    final response = await (client?.get ?? http.get)(Uri.parse(
            '$apiBase/auth/usernames/${Uri.encodeComponent(username)}'))
        .timeout(const Duration(seconds: 18));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> claim(String value,
      {required String token, http.Client? client}) async {
    final response = await (client?.patch ?? http.patch)(
      Uri.parse('$apiBase/users/me/username'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({'username': normalizedUsername(value)}),
    ).timeout(const Duration(seconds: 18));
    return _decode(response);
  }
}
