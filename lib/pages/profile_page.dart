// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import '../state.dart';
import '../widgets/game_ring.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _bio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bio.text = widget.app.bio50 ?? '';
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final me = app.me;

    final allGames = <String>{};
    for (final list in app.games.values) { allGames.addAll(list); }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(me.name, style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20)),
                if ((me.phone ?? '').isNotEmpty)
                  Text(me.phone!, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bio,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'بايو (50 حرف)'),
                  onChanged: (v)=> app.setBio(v),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        const Text('تقدّمك في الألعاب', style: TextStyle(
            fontWeight: FontWeight.w900)),

        const SizedBox(height: 8),

        Wrap(
          spacing: 10, runSpacing: 10,
          children: allGames.map((g){
            final info = app.levelForGame(me.name, g);
            final pts = me.pointsByGame[g] ?? 0;
            return Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameRing(size: 70, fill01: info.fill01),
                  const SizedBox(height: 8),
                  Text(g, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(info.name, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('النقاط: $pts', style: const TextStyle(color: Colors.white60)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
