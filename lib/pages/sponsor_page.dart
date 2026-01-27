// lib/pages/sponsor_page.dart
import 'package:flutter/material.dart';

import '../state.dart';
import '../api_sponsor.dart'; // ApiSponsors
import 'sponsor_game_page.dart';

class SponsorPage extends StatefulWidget {
  final AppState app;
  const SponsorPage({super.key, required this.app});

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  late Future<List<Map<String, dynamic>>> _sponsorsFuture;

  String? _openSponsorCode;
  Future<Map<String, dynamic>>? _sponsorDetailFuture;
  Future<List<Map<String, dynamic>>>? _walletsFuture;

  static const _fallbackSponsors = [
    {
      "code": "SP-BOBYAN",
      "name": "بوبيان",
      "active": true,
      "games": [
        {"gameId": "بلوت", "prizeAmount": 300, "game": {"id": "بلوت", "name": "بلوت"}},
        {"gameId": "كوت", "prizeAmount": 180, "game": {"id": "كوت", "name": "كوت"}},
      ],
    },
    {
      "code": "SP-OOREEDO",
      "name": "أوريدو",
      "active": true,
      "games": [
        {"gameId": "كونكان", "prizeAmount": 200, "game": {"id": "كونكان", "name": "كونكان"}},
        {"gameId": "دومينو", "prizeAmount": 120, "game": {"id": "دومينو", "name": "دومينو"}},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _sponsorsFuture = _loadSponsors();
  }

  Future<List<Map<String, dynamic>>> _loadSponsors() async {
    try {
      final list = await ApiSponsors.listSponsors();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // ignore and fallback
    }
    return _fallbackSponsors.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _openSponsor(String code) {
    setState(() {
      _openSponsorCode = code;
      _sponsorDetailFuture =
          ApiSponsors.getSponsorDetail(code: code, token: widget.app.token);
      _walletsFuture = (widget.app.token != null)
          ? ApiSponsors.getMyWallets(
        sponsorCode: code,
        token: widget.app.token!,
      )
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سبونسر'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sponsorsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('خطأ في تحميل الرعاة: ${snap.error}'),
            );
          }
          final sponsors = snap.data ?? [];
          if (sponsors.isEmpty) {
            return const Center(child: Text('لا يوجد رعاة حاليًا'));
          }

          // لو ما في راعي مفتوح، نختار الأول
          _openSponsorCode ??= (sponsors.first['code'] ?? '').toString();
          _sponsorDetailFuture ??= ApiSponsors.getSponsorDetail(
            code: _openSponsorCode!,
            token: widget.app.token,
          );
          _walletsFuture ??= (widget.app.token != null && widget.app.token!.isNotEmpty)
              ? ApiSponsors.getMyWallets(sponsorCode: _openSponsorCode!, token: widget.app.token!)
              : null;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SponsorPickerGrid(
                sponsors: sponsors,
                openCode: _openSponsorCode,
                onPick: _openSponsor,
              ),
              const SizedBox(height: 12),
              _openSponsorCode == null
                  ? const Text('اختر راعي لعرض الألعاب')
                  : _SponsorDetailSection(
                      app: app,
                      theme: theme,
                      sponsorCode: _openSponsorCode!,
                      sponsorDetailFuture: _sponsorDetailFuture!,
                      walletsFuture: _walletsFuture,
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _SponsorDetailSection extends StatelessWidget {
  final AppState app;
  final ThemeData theme;
  final String sponsorCode;
  final Future<Map<String, dynamic>> sponsorDetailFuture;
  final Future<List<Map<String, dynamic>>>? walletsFuture;

  const _SponsorDetailSection({
    required this.app,
    required this.theme,
    required this.sponsorCode,
    required this.sponsorDetailFuture,
    required this.walletsFuture,
  });

  List<Map<String, dynamic>> _mockBoard() => [
        {"displayName": "Nasser H.", "pearls": 5, "streak": 3},
        {"displayName": "Ahmad", "pearls": 4, "streak": 2},
        {"displayName": "Saad", "pearls": 3, "streak": 1},
      ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: sponsorDetailFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          return Text('خطأ في تحميل تفاصيل الراعي: ${snap.error}');
        }
        final data = snap.data ?? {};
        final sponsor = (data['sponsor'] as Map?)?.cast<String, dynamic>() ?? {};
        final games = (data['games'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final name = (sponsor['name'] ?? sponsorCode).toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SponsorHeroCard(
              sponsorName: name,
              sponsorCode: sponsorCode,
              onPlay: app.isSignedIn
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SponsorGameScreen(
                            app: app,
                            sponsorCode: sponsorCode,
                            initialGameId:
                                games.isNotEmpty ? (games.first['gameId'] ?? '').toString() : null,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            Text('ألعاب السبونسر', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (games.isEmpty)
              const Text('لا توجد ألعاب حالياً')
            else
              ...games.map((g) {
                final gameObj = (g['game'] as Map?) ?? {};
                final gid = (g['gameId'] ?? gameObj['id'] ?? '').toString();
                final gname = (gameObj['name'] ?? gid).toString();
                final prize = (g['prizeAmount'] as num?)?.toInt() ?? 0;
                final board = _mockBoard();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                gname,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF172133).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.card_giftcard, size: 18),
                                  const SizedBox(width: 6),
                                  Text('$prize'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('لوحة المتصدرين (تجريبية)', style: theme.textTheme.bodySmall),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: board.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (_, i) {
                            final row = board[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF273347),
                                child: Text('${i + 1}'),
                              ),
                              title: Text(row['displayName'].toString()),
                              subtitle: const Text('لآلئ السبونسر'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('lib/assets/pearl.png', width: 18, height: 18),
                                  const SizedBox(width: 6),
                                  Text('${row['pearls']}'),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
            if (walletsFuture != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('محافظك', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: walletsFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snap.hasError) {
                        return Text('خطأ في تحميل محافظك: ${snap.error}');
                      }
                      final wallets = snap.data ?? [];
                      if (wallets.isEmpty) return const Text('انضم مع الراعي لتحصل على لآلئ لكل لعبة');
                      return Column(
                        children: wallets.map((w) {
                          final game = (w['game'] as Map?) ?? {};
                          final gid = (game['id'] ?? '').toString();
                          final gname = (game['name'] ?? gid).toString();
                          final pearls = (w['pearls'] as num?)?.toInt() ?? 0;
                          return ListTile(
                            leading: const Icon(Icons.workspace_premium),
                            title: Text(gname),
                            subtitle: const Text('لآلئك لهذه اللعبة'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('lib/assets/pearl.png', width: 18, height: 18),
                                const SizedBox(width: 6),
                                Text('$pearls'),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _SponsorHeroCard extends StatelessWidget {
  final String sponsorName;
  final String sponsorCode;
  final VoidCallback? onPlay;
  const _SponsorHeroCard({
    required this.sponsorName,
    required this.sponsorCode,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sponsorName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text('كود: $sponsorCode', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                if (onPlay != null)
                  FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.sports_esports_outlined),
                    label: const Text('ابدأ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorPickerGrid extends StatelessWidget {
  final List<Map<String, dynamic>> sponsors;
  final String? openCode;
  final ValueChanged<String> onPick;
  const _SponsorPickerGrid({
    required this.sponsors,
    required this.openCode,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.7,
      children: sponsors.map((s) {
        final code = (s['code'] ?? '').toString();
        final name = (s['name'] ?? code).toString();
        final selected = code == openCode;
        return GestureDetector(
          onTap: () => onPick(code),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D6A7A), Color(0xFF23344A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFFF1A949) : Colors.white24,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
//sponsor_page.dart
