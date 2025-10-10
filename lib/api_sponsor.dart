import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class ApiSponsors {
  static Future<List<Map<String, dynamic>>> listSponsors() async {
    final res = await http.get(Uri.parse('$apiBase/sponsors'));
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw (m['message'] ?? 'Failed to load sponsors');
    }
    final data = m['data'];
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getSponsor(String code) async {
    final res = await http.get(Uri.parse('$apiBase/sponsors/$code'));
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw (m['message'] ?? 'Failed to load sponsor');
    }
    return (m['data'] as Map<String, dynamic>);
  }

  static Future<void> joinSponsor(String code, String token) async {
    final res = await http.post(
      Uri.parse('$apiBase/sponsors/$code/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw (m['message'] ?? 'Failed to join sponsor');
    }
  }

  static Future<List<Map<String, dynamic>>> myWallets(String code, String token) async {
    final res = await http.get(
      Uri.parse('$apiBase/sponsors/$code/wallets/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final m = jsonDecode(res.body);
    if (res.statusCode >= 400 || m['ok'] != true) {
      throw (m['message'] ?? 'Failed to load wallets');
    }
    final data = m['data'];
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.cast<Map<String, dynamic>>();
  }
}
