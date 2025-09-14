import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state.dart';
import '../api_room.dart';
import '../config.dart';

class MatchPage extends StatefulWidget {
  final AppState app;
  final Map<String, dynamic>? room; // {id, code, gameId, ...} from backend

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
    final roomId = (widget.room?['id'] ?? '').toString();

    // prod-style QR (HTTP path). For local dev you can point to API directly.
    final httpsLink = 'https://inzeli.app/join/$code';
    // final devLink  = 'http://10.0.2.2:3000/join/$code?userId=$guestUserId';

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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اكتب الكود')),
                    );
                    return;
                  }
                  try {
                    await joinByCode(code: inputCode, userId: guestUserId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joined ✅')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                },
                child: const Text('انضم'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          if (roomId.isNotEmpty) ...[
            const Text('اللاعبون:'),
            const SizedBox(height: 6),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: getPlayers(roomId),
              builder: (context, snap) {
                if (!snap.hasData) return const Text('…');
                final rows = snap.data!;
                if (rows.isEmpty) return const Text('لاعب واحد (أنت)');
                return Wrap(
                  spacing: 6,
                  children: rows.map((r) {
                    final user = r['user'] as Map<String, dynamic>?;
                    final name = user?['fullName'] ?? user?['email'] ?? r['userId'];
                    return Chip(label: Text(name.toString()));
                  }).toList(),
                );
              },
            ),
          ] else
            const Text('لا يوجد roomId — تأكد أنك مرّرت room من API عند فتح الصفحة.'),
        ],
      ),
    );
  }
}
