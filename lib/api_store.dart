// lib/api_store.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiStore {
  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Map<String, dynamic> _decode(http.Response res) {
    final m = jsonDecode(res.body);
    if (m is Map<String, dynamic>) return m;
    throw Exception('Bad response');
  }

  static Map<String, dynamic> _dataOrThrow(http.Response res, {String fallback = 'Failed'}) {
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = (m['message'] ?? fallback).toString();
      throw Exception(msg);
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : {'data': data};
  }

  static Future<List<Map<String, dynamic>>> listItems() async {
    final res = await http.get(Uri.parse('$apiBase/store')).timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw Exception((m['message'] ?? 'Failed to load store').toString());
    }
    final data = m['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  static Future<List<Map<String, dynamic>>> myItems({required String token}) async {
    final res = await http
        .get(Uri.parse('$apiBase/store/me'), headers: _headers(token: token))
        .timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw Exception((m['message'] ?? 'Failed to load items').toString());
    }
    final data = m['data'];
    if (data is List) {
      return data.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) {
          final item = (e['item'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          return {
            ...e,
            'item': item,
          };
        }
        return <String, dynamic>{};
      }).toList();
    }
    return const [];
  }

  static Future<Map<String, dynamic>> buyItem({
    required String token,
    required String itemId,
  }) async {
    final res = await http
        .post(Uri.parse('$apiBase/store/$itemId/buy'), headers: _headers(token: token))
        .timeout(_timeout);
    return _dataOrThrow(res, fallback: 'Purchase failed');
  }

  static Future<Map<String, dynamic>> applySelection({
    required String token,
    String? themeId,
    String? frameId,
    String? cardId,
  }) async {
    final body = <String, dynamic>{};
    if (themeId != null) body['themeId'] = themeId;
    if (frameId != null) body['frameId'] = frameId;
    if (cardId != null) body['cardId'] = cardId;

    final res = await http
        .post(
          Uri.parse('$apiBase/store/apply'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _dataOrThrow(res, fallback: 'Apply failed');
  }
}
