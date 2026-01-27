//player_profile_page.dart
import 'package:flutter/material.dart';
import '../state.dart';

class PlayerProfilePage extends StatelessWidget {
  final AppState app;
  final String playerName;
  const PlayerProfilePage({super.key, required this.app, required this.playerName});

  @override
  Widget build(BuildContext context) {
    String norm(String? s) => (s ?? '').trim().toLowerCase();
    final isMe = norm(playerName) == norm(app.displayName) ||
        norm(playerName) == norm(app.name) ||
        norm(playerName) == norm(app.email) ||
        norm(playerName) == norm(app.userId) ||
        norm(playerName) == norm(app.publicId);
    final isPrivate = (app.profilePrivate ?? false) && !isMe;
    final profileKey = isMe ? (app.displayName ?? playerName) : playerName;
    Map<String, dynamic>? backendProfile;
    if (app.userProfiles.containsKey(profileKey)) {
      backendProfile = app.userProfiles[profileKey];
    }
    final p = app.profile(profileKey) ??
        (backendProfile != null ? PlayerProfile(phone: backendProfile['phone']?.toString()) : null) ??
        (isMe ? PlayerProfile(phone: app.phone) : null);
    final stats = app.userStats[profileKey];
    final game = app.selectedGame ?? '';
    final pts = stats?['points'] ?? (p == null ? 0 : app.pointsOf(profileKey, game));
    final w = stats?['wins'] ?? (p == null ? 0 : app.winsOf(profileKey, game));
    final l = stats?['losses'] ?? (p == null ? 0 : app.lossesOf(profileKey, game));
    final matches = app.userMatches(profileKey);
    final bestGame = stats?['bestGame'] ?? (game.isNotEmpty ? app.gameLabel(game) : '—');
    final themeName = stats?['theme'] ?? app.themeId ?? 'افتراضي';
    final notFound = p == null && stats == null && backendProfile == null && !isMe;

    return Scaffold(
      appBar: AppBar(title: Text('ملف: $playerName')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(_initials(playerName))),
              title: Text(playerName, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: notFound
                  ? const Text('لا يوجد لاعب بهذا الاسم')
                  : (isPrivate ? const Text('الملف خاص') : Text(p?.phone ?? app.email ?? '—')),
              trailing: Text('اللعبة: $game'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatBox(title: 'النقاط', value: '$pts'),
                      const SizedBox(width: 8),
                      _StatBox(title: 'فوز', value: '$w'),
                      const SizedBox(width: 8),
                      _StatBox(title: 'خسارة', value: '$l'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text('أفضل لعبة: $bestGame', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Chip(
                        avatar: const Icon(Icons.style_outlined, size: 16),
                        label: Text('الثيم: $themeName'),
                      ),
                    ],
                  ),
                  if (isPrivate)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'الملف خاص — البيانات المفصّلة مخفية، يظهر فقط الفوز/الخسارة وأفضل لعبة والثيم.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!isPrivate && !notFound) ...[
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
//pages/player_profile_pages
