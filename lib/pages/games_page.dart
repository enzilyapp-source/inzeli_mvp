// lib/pages/games_page.dart
import 'package:flutter/material.dart';
import '../state.dart';
import '../api_room.dart';
import '../config.dart';            // <-- تأكدي من هذا
import 'match_page.dart';

class GamesPage extends StatefulWidget {
  final AppState app;
  const GamesPage({super.key, required this.app});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    final cats = app.categories;
    final selCat = app.selectedCategory ?? cats.first;
    final list = app.games[selCat]!;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // categories
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: cats.map((c) {
                final sel = c == selCat;
                return ChoiceChip(
                  selected: sel,
                  label: Text(c, style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: sel ? Colors.black : Colors.white,
                  )),
                  onSelected: (_) => setState(()=> app.pickCategory(c)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // games
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: list.map((g) {
                final sel = g == app.selectedGame;
                return FilterChip(
                  selected: sel,
                  label: Text(g, style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: sel ? Colors.black : Colors.white,
                  )),
                  onSelected: (_) => setState(()=> app.pickGame(g)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // انزلي → create room (backend)
        FilledButton.tonalIcon(
          icon: const Icon(Icons.qr_code_2),
          onPressed: () async {
            try {
              final gameId = app.selectedGame ?? 'بلياردو';
              // hostUserId قادم من config.dart
              final room = await createRoom(gameId: gameId, hostUserId: hostUserId);
              final code = (room['code'] ?? '').toString();
              app.roomCode = code;

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم إنشاء الروم: $code ✅')),
              );

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchPage(app: app, room: room)),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Create error: $e')),
              );
            }
          },
          label: const Text('انزلي'),
        ),
      ],
    );
  }
}
