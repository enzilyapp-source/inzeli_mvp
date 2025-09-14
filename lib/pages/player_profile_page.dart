//player_profile_page.dart
import 'package:flutter/material.dart';
import '../state.dart';

class PlayerProfilePage extends StatelessWidget {
  final AppState app;
  final String playerName;
  const PlayerProfilePage({super.key, required this.app, required this.playerName});

  @override
  Widget build(BuildContext context) {
    final p = app.profile(playerName);
    final game = app.selectedGame ?? '';
    final pts = app.pointsOf(playerName, game);
    final w   = app.winsOf(playerName, game);
    final l   = app.lossesOf(playerName, game);
    final matches = app.userMatches(playerName);

    return Scaffold(
      appBar: AppBar(title: Text('ملف: $playerName')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(_initials(playerName))),
              title: Text(playerName, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(p?.phone ?? '—'),
              trailing: Text('اللعبة: $game'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _StatBox(title: 'النقاط', value: '$pts'),
                  const SizedBox(width: 8),
                  _StatBox(title: 'فوز', value: '$w'),
                  const SizedBox(width: 8),
                  _StatBox(title: 'خسارة', value: '$l'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('آخر المباريات', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...matches.map((t)=> Card(
            child: ListTile(
              leading: const Icon(Icons.sports_esports_outlined),
              title: Text('${t.game} — ${t.roomCode}'),
              subtitle: Text(
                'فائز: ${t.winner} • خاسرون: ${t.losers.join("، ")}\n${t.ts}',
                maxLines: 2,
              ),
            ),
          )),
          if (matches.isEmpty)
            const Text('ما في مباريات لهذا اللاعب بعد', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title, value;
  const _StatBox({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEADFCC)),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s)=>s.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.characters.take(2).toString();
  return (parts[0].characters.take(1).toString() +
      parts[1].characters.take(1).toString());
}
