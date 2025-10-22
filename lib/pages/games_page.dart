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
  final _joinCode = TextEditingController();

  @override
  void dispose() {
    _joinCode.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final cats = app.categories;
    final selCat = app.selectedCategory ?? (cats.isNotEmpty ? cats.first : '');
    final list = app.games[selCat] ?? const <String>[];
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Categories
        if (cats.isNotEmpty)
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

        // Games
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

        // Create / Join
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ابدأ اللعب',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: onSurface)),
                const SizedBox(height: 10),

                // Create room
                FilledButton.icon(
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('إنشاء روم جديد'),
                  onPressed: () async {
                    if (!app.isSignedIn) {
                      _msg('سجّل دخول أول');
                      return;
                    }
                    try {
                      final gameId = app.selectedGame ?? 'BILLIARD';
                      final room = await ApiRoom.createRoom(
                        gameId: gameId,
                        hostUserId: app.userId,     // <- pass if available
                        token: app.token ?? '',      // <- pass token if available
                      );
                      app.roomCode = (room['code'] ?? '').toString();
                      if (!mounted) return;
                      _msg('تم إنشاء الروم: ${app.roomCode}');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchPage(app: app, room: room),
                        ),
                      );
                    } catch (e) {
                      _msg('Create error: $e');
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Join by code
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _joinCode,
                        decoration: const InputDecoration(
                          labelText: 'ادخل كود الروم',
                          hintText: 'مثال: AB12CD',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('انضمام'),
                      onPressed: () async {
                        if (!app.isSignedIn) {
                          _msg('سجّل دخول أول');
                          return;
                        }
                        final code = _joinCode.text.trim();
                        if (code.isEmpty) {
                          _msg('اكتبي الكود');
                          return;
                        }
                        try {
                          final room = await ApiRoom.joinByCode(
                            code: code,
                            userId: app.userId,      // <- pass if available
                            token: app.token ?? '',  // <- pass token if available
                          );
                          app.roomCode = code;
                          if (!mounted) return;
                          _msg('تم الانضمام ✅');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MatchPage(app: app, room: room),
                            ),
                          );
                        } catch (e) {
                          _msg('Join error: $e');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
