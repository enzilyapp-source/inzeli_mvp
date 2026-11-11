import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_base.dart';
import 'score_models.dart';

class ScoreApiError implements Exception {
  const ScoreApiError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Kept separate from room results: this API can never submit a win or move pearls.
class ScoreApi {
  ScoreApi({required this.code, required this.token, http.Client? client})
      : _client = client ?? http.Client();
  final String code;
  final String? token;
  final http.Client _client;
  Uri _url([String suffix = '']) => Uri.parse(
      '$apiBase/rooms/${Uri.encodeComponent(code)}/score-sheet$suffix');
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };
  Map<String, dynamic> _read(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ScoreApiError(
          response.statusCode, 'القيد يحتاج تحديث السيرفر. اللعب العادي متاح.');
    }
    if (response.statusCode == 401) {
      throw const ScoreApiError(401, 'انتهت الجلسة؛ سجّل دخولك مرة ثانية.');
    }
    if (response.statusCode == 403) {
      throw const ScoreApiError(
          403, 'عرض القيد لأعضاء القيم، والتعديل للهوست فقط.');
    }
    if (response.statusCode == 429) {
      throw const ScoreApiError(
          429, 'المزامنة مشغولة حاليًا؛ بنحاول مرة ثانية.');
    }
    if (response.statusCode >= 400 || body['ok'] != true) {
      throw ScoreApiError(
          response.statusCode,
          response.statusCode == 409
              ? 'تغير القيد من جهاز آخر. أعد تحميل النسخة المشتركة.'
              : response.statusCode == 404 || response.statusCode == 500
                  ? 'القيد غير متاح الآن؛ يحتاج تحديث السيرفر وقاعدة البيانات.'
                  : (body['message'] ?? 'تعذر مزامنة القيد').toString());
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<ScoreEnvelope> read() async =>
      ScoreEnvelope.fromJson(_read(await _client
          .get(_url(), headers: _headers)
          .timeout(const Duration(seconds: 12))));
  Future<ScoreEnvelope> write(int revision, ScoreSnapshot snapshot) async =>
      ScoreEnvelope.fromJson(_read(await _client
          .put(_url(),
              headers: _headers,
              body: jsonEncode(
                  {'revision': revision, 'snapshot': snapshot.toJson()}))
          .timeout(const Duration(seconds: 15))));
  Future<List<ScorePerson>> roster() async {
    final body = _read(await _client
        .get(_url('/roster'), headers: _headers)
        .timeout(const Duration(seconds: 15)));
    final people = <ScorePerson>[];
    for (final entry in body['players'] as List) {
      people.add(
          await ScorePerson.fromRoom(Map<String, dynamic>.from(entry as Map))
              .thumbnail());
    }
    return people;
  }

  void dispose() => _client.close();
}
