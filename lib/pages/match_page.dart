// lib/pages/match_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';
import '../config.dart';  // <-- مهم

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room; // { code, gameId, ... } from backend

  const MatchPage({super.key, required this.app, this.room});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _codeCtrl = TextEditingController();
  @override void dispose() { _codeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final code   = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game   = (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة').toString();

    final httpsLink = 'https://inzeli.app/join/$code';

    return Scaffold(
      appBar: AppBar(title: Text('مباراة $game — كود: ${code.isEmpty ? "—" : code}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (code.isNotEmpty) ...[
            Center(child: QrImageView(data: httpsLink, size: 220, backgroundColor: Colors.white)),
            const SizedBox(height: 8),
            SelectableText('كود الروم: $code', textAlign: TextAlign.center),
          ] else
            const Text('لا يوجد كود — ارجع وأنشئ روم من “انزلي”.'),

          const SizedBox(height: 20),
          const Text('انضم بالكود (اختبار بدون سكان)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'اكتب كود الروم'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final inputCode = _codeCtrl.text.trim();
                  if (inputCode.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب الكود')));
                    return;
                  }
                  try {
                    await joinByCode(code: inputCode, userId: guestUserId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined ✅')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                },
                child: const Text('انضم'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          if (code.isNotEmpty) ...[
            const Text('اللاعبون:'),
            const SizedBox(height: 6),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: getPlayers(code),   // <-- هنا صار الكود
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('خطأ: ${snap.error}');
                }
                final rows = snap.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return const Text('لاعب واحد (أنت)');
                return Wrap(
                  spacing: 6,
                  children: rows.map((r) {
                    final userId = r['userId']?.toString() ?? '—';
                    return Chip(label: Text(userId));
                  }).toList(),
                );
              },
            ),
          ] else
            const Text('لا يوجد كود — تأكد أنك مرّرت room من API عند فتح الصفحة.'),
        ],
      ),
    );
  }
}
