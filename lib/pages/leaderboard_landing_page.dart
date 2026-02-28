import 'package:flutter/material.dart';

import '../state.dart';
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

  @override
  Widget build(BuildContext context) {
    final sponsor = sponsors.firstWhere((s) => s.code == selectedSponsorCode, orElse: () => sponsors.first);
    final games = sponsor.games;
    selectedSponsorGameId ??= games.isNotEmpty ? games.first.gameId : null;

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
                  backgroundColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.08)),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Removed mock leaderboards; real lists موجودة بالخارج
            const Spacer(),

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
