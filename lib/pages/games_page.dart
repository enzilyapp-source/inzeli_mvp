import 'package:flutter/material.dart';
import '../state.dart';
import '../api_room.dart';
import 'match_page.dart';

class GamesPage extends StatefulWidget {
  final AppState app;
  const GamesPage({super.key, required this.app});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final cats = app.categories;
    final selCat = app.selectedCategory ?? cats.first;
    final list = app.games[selCat]!;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ... أقسامك نفسها ...
        FilledButton.tonalIcon(
          icon: const Icon(Icons.qr_code_2),
          onPressed: () async {
            if (!app.isSignedIn) { _msg('سجّل دخول أول'); return; }
            try {
              final gameId = app.selectedGame ?? 'بلياردو';
              final room = await createRoom(
                gameId: gameId,
                hostUserId: app.userId!,      // <-- هوية اللاعب من الأوث
                token: app.token,             // (لو فعلتِ Guard لاحقًا)
              );
              final code = (room['code'] ?? '').toString();
              app.roomCode = code;
              _msg('تم إنشاء الروم: $code');

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchPage(app: app, room: room)),
              );
            } catch (e) {
              if (!mounted) return;
              _msg('Create error: $e');
            }
          },
          label: const Text('انزلي'),
        ),
      ],
    );
  }
}
