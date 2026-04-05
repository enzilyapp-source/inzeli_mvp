import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiResponse<T> {
  final bool ok;
  final String message;
  final T? data;
  final String? code;

  ApiResponse({
    required this.ok,
    required this.message,
    this.data,
    this.code,
  });

  static ApiResponse<Map<String, dynamic>> fromHttp(http.Response res) {
    try {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final code = (m['code'] as String?)?.trim();
      final rawMessage = (m['message'] ?? 'No message').toString();
      return ApiResponse(
        ok: m['ok'] == true,
        message: _friendlyAuthMessage(rawMessage, code),
        data: m['data'] as Map<String, dynamic>?,
        code: code,
      );
    } catch (_) {
      return ApiResponse(
        ok: false,
        message: 'Bad server response (${res.statusCode})',
      );
    }
  }
}

String _friendlyAuthMessage(String message, String? code) {
  final key = (code?.isNotEmpty ?? false) ? code! : message;
  switch (key) {
    case 'EMAIL_EXISTS':
      return 'هذا الإيميل مستخدم من قبل';
    case 'PHONE_EXISTS':
      return 'رقم الجوال مستخدم من قبل';
    case 'PHONE_REQUIRED':
      return 'رقم الجوال مطلوب';
    case 'INVALID_PHONE':
      return 'رقم الجوال غير صحيح';
    case 'OTP_RATE_LIMIT':
      return 'تم إرسال رمز قبل لحظات، حاول بعد قليل';
    case 'OTP_PROVIDER_NOT_CONFIGURED':
      return 'خدمة رسائل OTP غير مفعلة على الخادم';
    case 'OTP_SEND_FAILED':
      return 'تعذّر إرسال رمز التحقق، حاول مرة أخرى';
    case 'OTP_NOT_FOUND':
      return 'طلب التحقق غير موجود أو منتهي';
    case 'OTP_INVALID':
      return 'رمز التحقق غير صحيح';
    case 'OTP_EXPIRED':
      return 'رمز التحقق منتهي الصلاحية';
    case 'OTP_TOO_MANY_ATTEMPTS':
      return 'تم تجاوز عدد المحاولات، أعد إرسال الرمز';
    case 'OTP_ALREADY_USED':
      return 'هذا الرمز تم استخدامه مسبقًا';
    case 'PHONE_NOT_VERIFIED':
      return 'رقم الجوال غير موثّق';
    case 'INVALID_CREDENTIALS':
      return 'بيانات الدخول غير صحيحة';
    default:
      return message;
  }
}

Future<ApiResponse<Map<String, dynamic>>> _post(
  String path,
  Map<String, dynamic> body,
) async {
  try {
    final res = await http
        .post(
          Uri.parse('$apiBase$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 18));

    // ignore: avoid_print
    print('AUTH $path → ${res.statusCode} ${res.body}');
    return ApiResponse.fromHttp(res);
  } catch (e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    final looksLikeNetwork = lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup') ||
        lower.contains('timeout') ||
        lower.contains('handshake');
    final msg = looksLikeNetwork
        ? 'تعذر الاتصال بالخادم. تأكد من الإنترنت ورابط الـ API: $apiBase'
        : raw;
    return ApiResponse(ok: false, message: msg);
  }
}

Future<ApiResponse<Map<String, dynamic>>> requestRegisterOtp({
  required String email,
  required String password,
  required String displayName,
  required String phone,
  String? birthDate,
}) =>
    _post('/auth/register/request-otp', {
      'email': email,
      'password': password,
      'displayName': displayName,
      'phone': phone,
      if (birthDate != null) 'birthDate': birthDate,
    });

Future<ApiResponse<Map<String, dynamic>>> verifyRegisterOtp({
  required String requestId,
  required String code,
}) =>
    _post('/auth/register/verify-otp', {
      'requestId': requestId,
      'code': code,
    });

// legacy alias
Future<ApiResponse<Map<String, dynamic>>> register({
  required String email,
  required String password,
  required String displayName,
  required String phone,
  String? birthDate,
}) =>
    requestRegisterOtp(
      email: email,
      password: password,
      displayName: displayName,
      phone: phone,
      birthDate: birthDate,
    );

Future<ApiResponse<Map<String, dynamic>>> login({
  required String email,
  required String password,
}) =>
    _post('/auth/login', {
      'email': email,
      'password': password,
    });

//api_auth.dart
