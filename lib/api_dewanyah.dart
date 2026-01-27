import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiDewanyah {
  static const _timeout = Duration(seconds: 15);

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _decode(http.Response res) {
    final m = jsonDecode(res.body);
    if (m is Map<String, dynamic>) return m;
    throw Exception('Invalid JSON');
  }

  static Map<String, dynamic> _dataOrThrow(http.Response res, {String fallback = 'Request failed'}) {
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = m['message']?.toString() ?? fallback;
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = m['data'];
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  // POST /dewanyah/requests
  static Future<Map<String, dynamic>> createRequest({
    required String name,
    required String contact,
    String? gameId,
    String? note,
    bool? requireApproval,
    bool? locationLock,
    int? radiusMeters,
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/dewanyah/requests'),
          headers: _headers(token),
          body: jsonEncode({
            'name': name,
            'contact': contact,
            if (gameId != null) 'gameId': gameId,
            if (note != null) 'note': note,
            if (requireApproval != null) 'requireApproval': requireApproval,
            if (locationLock != null) 'locationLock': locationLock,
            if (radiusMeters != null) 'radiusMeters': radiusMeters,
          }),
        )
        .timeout(_timeout);
    return _dataOrThrow(res, fallback: 'Failed to submit request');
  }

  // POST /dewanyah/:id/join
  static Future<void> requestJoin({
    required String dewanyahId,
    required String? token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/dewanyah/$dewanyahId/join'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = m['message']?.toString() ?? 'Failed to join';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
  }

  // GET /dewanyah/:id/leaderboard
  static Future<List<Map<String, dynamic>>> leaderboard({
    required String dewanyahId,
    int limit = 100,
  }) async {
    final res = await http
        .get(
          Uri.parse('$apiBase/dewanyah/$dewanyahId/leaderboard?limit=$limit'),
          headers: _headers(null),
        )
        .timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = m['message']?.toString() ?? 'Failed to load leaderboard';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = m['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  // GET /dewanyah
  static Future<List<Map<String, dynamic>>> listAll() async {
    final res = await http.get(Uri.parse('$apiBase/dewanyah')).timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = m['message']?.toString() ?? 'Failed to load';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = m['data'];
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return const [];
  }

  // GET /dewanyah/:id/members (owner only)
  static Future<List<Map<String, dynamic>>> members({
    required String dewanyahId,
    required String? token,
  }) async {
    final res = await http
        .get(Uri.parse('$apiBase/dewanyah/$dewanyahId/members'), headers: _headers(token))
        .timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = m['message']?.toString() ?? 'Failed to load members';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = m['data'];
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return const [];
  }

  // PATCH /dewanyah/:id/members/:userId/status
  static Future<void> setMemberStatus({
    required String dewanyahId,
    required String memberUserId,
    required String status,
    required String? token,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$apiBase/dewanyah/$dewanyahId/members/$memberUserId/status'),
          headers: _headers(token),
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);
    final m = _decode(res);
    if (res.statusCode >= 400 || m['ok'] != true) {
      final msg = m['message']?.toString() ?? 'Failed to update status';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
  }
}
