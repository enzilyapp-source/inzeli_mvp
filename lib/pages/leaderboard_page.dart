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
  String? selectedCat;
  String? selectedGame;

  @override
  void initState() {
    super.initState();
    final app = widget.app;
    selectedCat = app.selectedCategory ?? (app.categories.isNotEmpty ? app.categories.first : null);
    final list = (selectedCat == null) ? const <String>[] : (app.games[selectedCat] ?? const <String>[]);
    selectedGame = app.selectedGame ?? (list.isNotEmpty ? list.first : null);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: app.categories.map((cat) {
                        final sel = cat == selectedCat;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            selected: sel,
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: sel ? Colors.black : Colors.white,
                              ),
                            ),
                            onSelected: (_) {
                              setState(() {
                                selectedCat = cat;
                                final list = app.games[cat] ?? const <String>[];
                                selectedGame = list.isNotEmpty ? list.first : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Games
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (app.games[selectedCat] ?? const <String>[]).map((g) {
                        final sel = g == selectedGame;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            selected: sel,
                            label: Text(
                              g,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: sel ? Colors.black : Colors.white,
                              ),
                            ),
                            onSelected: (_) => setState(() => selectedGame = g),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              selectedGame == null ? 'اختر لعبة' : 'مراتب — ${selectedCat ?? ""} / ${selectedGame!}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: FutureBuilder<List<LBRow>>(
              future: app.getLeaderboard(selectedGame),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}'));
                }

                final rows = snap.data ?? const <LBRow>[];
                if (rows.isEmpty) return const Center(child: Text('ما فيه نتائج لهاللعبة بعد'));

                final top3 = rows.take(3).toList();
                final rest = rows.length > 3 ? rows.sublist(3) : <LBRow>[];

                return LayoutBuilder(
                  builder: (context, cons) {
                    final w = cons.maxWidth;
                    final podiumHeight = w < 360 ? 108.0 : (w < 420 ? 130.0 : 150.0);

                    return ListView(
                      children: [
                        // Podium
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (top3.length >= 2)
                              Expanded(
                                child: _PodiumCell(
                                  row: top3[1],
                                  rank: 2,
                                  height: podiumHeight * 0.82,
                                  onTap: () => _openPlayer(top3[1].name),
                                ),
                              ),
                            if (top3.isNotEmpty)
                              Expanded(
                                child: _PodiumCell(
                                  row: top3[0],
                                  rank: 1,
                                  height: podiumHeight,
                                  onTap: () => _openPlayer(top3[0].name),
                                ),
                              ),
                            if (top3.length >= 3)
                              Expanded(
                                child: _PodiumCell(
                                  row: top3[2],
                                  rank: 3,
                                  height: podiumHeight * 0.75,
                                  onTap: () => _openPlayer(top3[2].name),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (rest.isNotEmpty) ...[
                          if (w >= 540)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 2.6,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemCount: rest.length,
                              itemBuilder: (context, i) {
                                final r = rest[i];
                                final rank = i + 4;
                                return _PlayerCard(row: r, rank: rank, onTap: () => _openPlayer(r.name));
                              },
                            )
                          else
                            ...List.generate(rest.length, (i) {
                              final r = rest[i];
                              final rank = i + 4;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PlayerCard(row: r, rank: rank, onTap: () => _openPlayer(r.name)),
                              );
                            }),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openPlayer(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerProfilePage(app: widget.app, playerName: name)),
    );
  }
}

class _PodiumCell extends StatelessWidget {
  final LBRow row;
  final int rank;
  final double height;
  final VoidCallback onTap;
  const _PodiumCell({required this.row, required this.rank, required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final color = rank == 1
        ? const Color(0xFFFFD54F)
        : rank == 2
        ? const Color(0xFFB0BEC5)
        : const Color(0xFFBCAAA4);

    final initials = _initials(row.name);
    final h = height + 8;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.35),
              child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.1),
            ),
            Text(
              '$medal نقاط: ${row.pts}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final LBRow row;
  final int rank;
  final VoidCallback onTap;
  const _PlayerCard({required this.row, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeColor = const Color(0xFFC5533C);
    final initials = _initials(row.name);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Card(
        elevation: 1.2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEADFCC)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$rank', style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3A2A22).withOpacity(0.10),
                child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ف:${row.w} • خ:${row.l}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${row.pts} نقاط', style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.characters.take(2).toString();
  return (parts[0].characters.take(1).toString() + parts[1].characters.take(1).toString());
}
//leaderboard_page.dart