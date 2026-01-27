import 'package:flutter/material.dart';
import '../state.dart';
import 'player_profile_page.dart';

class LeaderboardPage extends StatefulWidget {
  final AppState app;
  const LeaderboardPage({super.key, required this.app});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final List<String> _games;
  late final PageController _pageCtrl;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    final app = widget.app;
    final all = <String>{};
    for (final list in app.games.values) {
      all.addAll(list);
    }
    _games = all.toList();
    _games.sort();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    if (_games.isEmpty) {
      return const Center(child: Text('لا توجد ألعاب متاحة حالياً'));
    }

    final currentGame = _games[_pageIndex.clamp(0, _games.length - 1)];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'المراتب العامة — ${app.gameLabel(currentGame)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text('${_pageIndex + 1}/${_games.length}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _games.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (_, i) => _GameLeaderboard(
              app: app,
              game: _games[i],
              onOpenPlayer: _openPlayer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_games.length, (i) {
            final active = i == _pageIndex;
            return Container(
              width: active ? 14 : 8,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: active ? 0.9 : 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _openPlayer(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerProfilePage(app: widget.app, playerName: name)),
    );
  }
}

class _GameLeaderboard extends StatelessWidget {
  final AppState app;
  final String game;
  final void Function(String name) onOpenPlayer;
  const _GameLeaderboard({required this.app, required this.game, required this.onOpenPlayer});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LBRow>>(
      future: app.getLeaderboard(game),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('خطأ: ${snap.error}'));
        }
        final rows = snap.data ?? const <LBRow>[];
        if (rows.isEmpty) return const Center(child: Text('ما فيه نتائج لهاللعبة بعد'));

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    final rank = i + 1;
                    return _PlayerPearlRow(
                      row: row,
                      rank: rank,
                      onTap: () => onOpenPlayer(row.name),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerPearlRow extends StatelessWidget {
  final LBRow row;
  final int rank;
  final VoidCallback onTap;
  const _PlayerPearlRow({required this.row, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    final avatar = CircleAvatar(
      radius: 20,
      backgroundColor: isTop ? const Color(0xFFFFC16B) : Colors.white12,
      child: Text(
        row.name.isNotEmpty ? row.name.characters.first : '?',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isTop ? Colors.black : Colors.white,
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop ? const Color(0xFFFFA53A) : Colors.white.withValues(alpha: 0.1),
            width: isTop ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                if (isTop)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA53A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'الأول',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'لآلئ: ${row.pts}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, size: 16, color: Color(0xFFFFC16B)),
                  const SizedBox(width: 6),
                  Text('${row.pts}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


//leaderboard_page.dart
