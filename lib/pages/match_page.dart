import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room; // { code, gameId, ... }
  const MatchPage({super.key, required this.app, this.room});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _codeCtrl = TextEditingController();
  @override void dispose() { _codeCtrl.dispose(); super.dispose(); }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final code = (widget.room?['code'] ?? widget.app.roomCode ?? '').toString();
    final game = (widget.room?['gameId'] ?? widget.app.selectedGame ?? 'لعبة').toString();
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
                  if (inputCode.isEmpty) { _msg('اكتب الكود'); return; }
                  if (!widget.app.isSignedIn) { _msg('سجّل دخول أول'); return; }
                  try {
                    await joinByCode(code: inputCode, userId: widget.app.userId!, token: widget.app.token);
                    _msg('Joined ✅');
                  } catch (e) { _msg('خطأ: $e'); }
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
              future: getPlayers(code, token: widget.app.token),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return Text('خطأ: ${snap.error}');
                final rows = snap.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return const Text('لاعب واحد (أنت)');
                return Wrap(
                  spacing: 6,
                  children: rows.map((r) {
                    final uid = r['userId']?.toString() ?? '—';
                    return Chip(label: Text(uid));
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
