import 'package:flutter/material.dart';

import '../state.dart';
import '../widgets/streak_flame.dart';
import '../widgets/pearl_badge.dart';

import 'games_page.dart';
import 'sponsor_page.dart';

class LeaderboardLandingPage extends StatefulWidget {
  final AppState app;
  const LeaderboardLandingPage({super.key, required this.app});

  @override
  State<LeaderboardLandingPage> createState() => _LeaderboardLandingPageState();
}

class _LeaderboardLandingPageState extends State<LeaderboardLandingPage> {
  int tab = 0; // 0=إنزلي , 1=إنزلي سبونسر

  // ---------------- Mock Data ----------------
  final List<_LBUser> regularTop = const [
    _LBUser(name: 'Nasser Hna', pearls: 18, wins: 230, losses: 41, streak: 7, games: ['بلوت','كوت','تريكس']),
    _LBUser(name: 'Ahmad',      pearls: 12, wins: 100, losses: 22, streak: 3, games: ['شطرنج','تريكس']),
    _LBUser(name: 'Saad',       pearls:  7, wins:  50, losses: 19, streak: 1, games: ['كوت']),
    _LBUser(name: 'Fatema',     pearls: 10, wins:  88, losses: 30, streak: 5, games: ['سبيتة','بلوت']),
    _LBUser(name: 'Mariam',     pearls:  5, wins:  33, losses: 17, streak: 2, games: ['شطرنج']),
  ];

  final List<_SponsorMock> sponsors = const [
    _SponsorMock(
      code: 'SP-KFH',
      name: 'بيتك',
      games: [
        _SponsorGameMock(gameId: 'بلوت', prize: 300),
        _SponsorGameMock(gameId: 'كوت', prize: 200),
      ],
    ),
    _SponsorMock(
      code: 'SP-ZAIN',
      name: 'زين',
      games: [
        _SponsorGameMock(gameId: 'سبيتة', prize: 250),
        _SponsorGameMock(gameId: 'تريكس', prize: 150),
      ],
    ),
    _SponsorMock(
      code: 'SP-OREEDOO',
      name: 'أوريدو',
      games: [
        _SponsorGameMock(gameId: 'بولنج', prize: 120),
        _SponsorGameMock(gameId: 'بادل', prize: 500),
      ],
    ),
  ];

  String? selectedSponsorCode;
  String? selectedSponsorGameId;

  final Map<String, List<_LBUser>> sponsorBoards = const {
    'SP-KFH|بلوت': [
      _LBUser(name: 'Nasser Hna', pearls: 14, wins: 31, losses: 8,  streak: 6, games: ['بلوت']),
      _LBUser(name: 'Ahmad',      pearls: 10, wins: 18, losses: 9,  streak: 2, games: ['بلوت','كوت']),
      _LBUser(name: 'Saad',       pearls:  7, wins: 10, losses: 7,  streak: 4, games: ['بلوت']),
    ],
    'SP-KFH|كوت': [
      _LBUser(name: 'Mariam',     pearls:  9, wins: 14, losses: 5,  streak: 3, games: ['كوت']),
      _LBUser(name: 'Ahmad',      pearls:  6, wins: 11, losses: 9,  streak: 2, games: ['كوت']),
    ],
    'SP-ZAIN|سبيتة': [
      _LBUser(name: 'Fatema',     pearls: 12, wins: 22, losses: 4,  streak: 7, games: ['سبيتة']),
      _LBUser(name: 'Saad',       pearls:  6, wins:  3, losses: 9,  streak: 1, games: ['سبيتة']),
    ],
    'SP-OREEDOO|بادل': [
      _LBUser(name: 'Ahmad',      pearls: 15, wins: 40, losses: 12, streak: 9, games: ['بادل','بولنج']),
      _LBUser(name: 'Mariam',     pearls:  8, wins: 18, losses: 14, streak: 2, games: ['بادل']),
    ],
  };

  @override
  void initState() {
    super.initState();
    selectedSponsorCode ??= sponsors.first.code;
    selectedSponsorGameId ??= sponsors.first.games.first.gameId;
  }

  IconData _gameIcon(String game) {
    switch (game.trim()) {
      case 'بلوت': return Icons.style;
      case 'كوت': return Icons.grid_4x4;
      case 'تريكس': return Icons.extension;
      case 'سبيتة': return Icons.casino;
      case 'شطرنج': return Icons.emoji_events;
      case 'بادل': return Icons.sports_tennis;
      case 'بولنج': return Icons.sports;
      case 'بلياردو': return Icons.sports_bar;
      default: return Icons.sports_esports;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sponsor = sponsors.firstWhere((s) => s.code == selectedSponsorCode, orElse: () => sponsors.first);
    final games = sponsor.games;
    selectedSponsorGameId ??= games.isNotEmpty ? games.first.gameId : null;

    final key = '${selectedSponsorCode ?? ''}|${selectedSponsorGameId ?? ''}';
    final sponsorRows = sponsorBoards[key] ?? const <_LBUser>[];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
          Color(0xFF232E4A),
          Color(0xFF34677A),
        ]),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('المراتب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  PearlBadge(pearls: widget.app.creditPoints ?? 5, emphasized: true),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('إنزلي')),
                  ButtonSegment(value: 1, label: Text('إنزلي سبونسر')),
                ],
                selected: {tab},
                onSelectionChanged: (s) => setState(() => tab = s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.08)),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  if (tab == 0) ...[
                    const _SectionTitle('Top Players — إنزلي', icon: Icons.public),
                    const SizedBox(height: 10),
                    ..._rankify(regularTop).map((e) => _LeaderboardTile(
                      rank: e.$1,
                      row: e.$2,
                      gameIcon: _gameIcon,
                      rightBadge: _PearlPill(value: e.$2.pearls, label: 'لؤلؤة'),
                    )),
                    const SizedBox(height: 10),
                    const _HintCard(
                      text:
                      '• اللآلئ هنا شهرية.\n'
                          '• الفوز/الخسارة هنا Lifetime (مثال).',
                    ),
                  ] else ...[
                    const _SectionTitle('Top Players — سبونسر', icon: Icons.workspace_premium_outlined),
                    const SizedBox(height: 10),

                    _SponsorPicker(
                      sponsors: sponsors,
                      selectedCode: selectedSponsorCode!,
                      onPick: (c) {
                        setState(() {
                          selectedSponsorCode = c;
                          final sp = sponsors.firstWhere((s) => s.code == c);
                          selectedSponsorGameId = sp.games.isNotEmpty ? sp.games.first.gameId : null;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    if (games.isNotEmpty)
                      _GamePicker(
                        games: games,
                        selectedGameId: selectedSponsorGameId,
                        onPick: (g) => setState(() => selectedSponsorGameId = g),
                      ),

                    const SizedBox(height: 10),

                    if (selectedSponsorGameId != null)
                      _PrizeBanner(
                        sponsorName: sponsor.name,
                        gameId: selectedSponsorGameId!,
                        prize: games.firstWhere((g) => g.gameId == selectedSponsorGameId, orElse: () => games.first).prize,
                      ),

                    const SizedBox(height: 10),

                    if (sponsorRows.isEmpty)
                      const _HintCard(text: 'ما فيه نتائج لهاللعبة عند هالسبونسر (Mock).')
                    else ...[
                      ..._rankify(sponsorRows).map((e) => _LeaderboardTile(
                        rank: e.$1,
                        row: e.$2,
                        gameIcon: _gameIcon,
                        rightBadge: _PearlPill(value: e.$2.pearls, label: 'لؤلؤة سبونسر'),
                      )),
                      const SizedBox(height: 10),
                      const _HintCard(
                        text:
                        '• لآلئ السبونسر تظهر داخل السبونسر فقط.\n'
                            '• النتائج هنا داخل نطاق (Sponsor + Game).',
                      ),
                    ],
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A00),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  onPressed: () {
                    if (tab == 0) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => GamesPage(app: widget.app)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SponsorPage(app: widget.app)));
                    }
                  },
                  child: Text(widget.app.tr(ar: 'انزلي', en: 'Start')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(int, _LBUser)> _rankify(List<_LBUser> rows) {
    final sorted = [...rows]..sort((a, b) => b.pearls.compareTo(a.pearls));
    return List.generate(sorted.length, (i) => (i + 1, sorted[i]));
  }
}

/* -------------------- UI pieces -------------------- */

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionTitle(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final _LBUser row;
  final Widget rightBadge;
  final IconData Function(String) gameIcon;

  const _LeaderboardTile({
    required this.rank,
    required this.row,
    required this.rightBadge,
    required this.gameIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          _RankBox(rank: rank),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.10),
            child: Text(_initials(row.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (row.streak >= 2) ...[
                    const SizedBox(width: 8),
                    StreakFlame(streak: row.streak, compact: true),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('ف:${row.wins} • خ:${row.losses}', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),

                if (row.games.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: row.games.take(5).map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(gameIcon(g), size: 14, color: Colors.white.withOpacity(0.9)),
                            const SizedBox(width: 6),
                            Text(g, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),
          rightBadge,
        ],
      ),
    );
  }
}

class _RankBox extends StatelessWidget {
  final int rank;
  const _RankBox({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

class _PearlPill extends StatelessWidget {
  final int value;
  final String label;
  const _PearlPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/assets/pearl.png',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 6),
          Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
        ],
      ),
    );
  }
}

class _SponsorPicker extends StatelessWidget {
  final List<_SponsorMock> sponsors;
  final String selectedCode;
  final ValueChanged<String> onPick;

  const _SponsorPicker({
    required this.sponsors,
    required this.selectedCode,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sponsors.map((s) {
        final selected = s.code == selectedCode;
        return ChoiceChip(
          selected: selected,
          label: Text(s.name),
          onSelected: (_) => onPick(s.code),
          selectedColor: Colors.white.withOpacity(0.22),
          backgroundColor: Colors.white.withOpacity(0.08),
          labelStyle: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
        );
      }).toList(),
    );
  }
}

class _GamePicker extends StatelessWidget {
  final List<_SponsorGameMock> games;
  final String? selectedGameId;
  final ValueChanged<String> onPick;

  const _GamePicker({
    required this.games,
    required this.selectedGameId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: games.map((g) {
        final selected = g.gameId == selectedGameId;
        return FilterChip(
          selected: selected,
          label: Text('${g.gameId} • جائزة ${g.prize}'),
          onSelected: (_) => onPick(g.gameId),
          selectedColor: Colors.white.withOpacity(0.22),
          backgroundColor: Colors.white.withOpacity(0.08),
          labelStyle: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
        );
      }).toList(),
    );
  }
}

class _PrizeBanner extends StatelessWidget {
  final String sponsorName;
  final String gameId;
  final int prize;

  const _PrizeBanner({
    required this.sponsorName,
    required this.gameId,
    required this.prize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$sponsorName • $gameId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
            child: Text('الجائزة: $prize', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String text;
  const _HintCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85))),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return (parts[0].characters.take(1).toString() + parts[1].characters.take(1).toString()).toUpperCase();
}

/* -------------------- Models -------------------- */

class _LBUser {
  final String name;
  final int pearls;
  final int wins;
  final int losses;
  final int streak;
  final List<String> games;

  const _LBUser({
    required this.name,
    required this.pearls,
    required this.wins,
    required this.losses,
    required this.streak,
    this.games = const [],
  });
}

class _SponsorMock {
  final String code;
  final String name;
  final List<_SponsorGameMock> games;
  const _SponsorMock({required this.code, required this.name, required this.games});
}

class _SponsorGameMock {
  final String gameId;
  final int prize;
  const _SponsorGameMock({required this.gameId, required this.prize});
}
