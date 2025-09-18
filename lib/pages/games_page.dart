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
  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final cats = app.categories;
    final selCat = app.selectedCategory ?? cats.first;
    final list = app.games[selCat] ?? const <String>[];

    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // الفئات
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.map((c) {
                final sel = c == selCat;
                return ChoiceChip(
                  selected: sel,
                  label: Text(
                    c,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: sel ? onSurface : onSurface.withOpacity(0.9),
                    ),
                  ),
                  onSelected: (_) => setState(() => app.pickCategory(c)),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // الألعاب
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: list.map((g) {
                final sel = g == app.selectedGame;
                return FilterChip(
                  selected: sel,
                  label: Text(
                    g,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: sel ? onSurface : onSurface.withOpacity(0.9),
                    ),
                  ),
                  onSelected: (_) => setState(() => app.pickGame(g)),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // إنشاء روم
        FilledButton.tonalIcon(
          icon: const Icon(Icons.qr_code_2),
          label: const Text('انزلي'),
          onPressed: () async {
            if (!app.isSignedIn) {
              _msg('سجّلي دخول أول');
              return;
            }
            try {
              final gameId = app.selectedGame ?? 'بلياردو';
              final room = await createRoom(
                gameId: gameId,
                hostUserId: app.userId!, // مهم: هوية اللاعب من الأوث
                token: app.token,         // لو فعلتِ Guard في الباكند
              );
              final code = (room['code'] ?? '').toString();
              app.roomCode = code;

              if (!mounted) return;
              _msg('تم إنشاء الروم: $code');

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchPage(app: app, room: room)),
              );
            } catch (e) {
              if (!mounted) return;
              _msg('Create error: $e');
            }
          },
        ),
      ],
    );
  }
}
