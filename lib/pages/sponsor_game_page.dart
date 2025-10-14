import 'package:flutter/material.dart';
import '../state.dart';
import '../api_sponsor.dart';

/// Per-sponsor, per-game screen (e.g., Sponsor SP-TEST, Game CHESS)
class SponsorGameScreen extends StatefulWidget {
  final AppState app;
  final String sponsorCode;
  final String gameId;
  final String gameName;

  const SponsorGameScreen({
    super.key,
    required this.app,
    required this.sponsorCode,
    required this.gameId,
    required this.gameName,
  });

  @override
  State<SponsorGameScreen> createState() => _SponsorGameScreenState();
}

class _SponsorGameScreenState extends State<SponsorGameScreen> {
  Future<Map<String, dynamic>>? _walletFuture;          // { userId, sponsorCode, gameId, pearls }
  Future<List<Map<String, dynamic>>>? _leaderboardFuture; // [{userId,name,pearls}, ...]

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _reload() {
    // create/read wallet only if signed in
    if (widget.app.isSignedIn) {
      _walletFuture = ApiSponsors.getOrCreateWallet(
        sponsorCode: widget.sponsorCode,
        gameId: widget.gameId,
        token: widget.app.token!,
      );
    } else {
      _walletFuture = Future.value(<String, dynamic>{});
    }
    _leaderboardFuture = ApiSponsors.leaderboard(
      sponsorCode: widget.sponsorCode,
      gameId: widget.gameId,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gameName} — ${widget.sponsorCode}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Wallet card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'رصيدي في ${widget.gameName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _walletFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!widget.app.isSignedIn) {
                        return const Text('سجّل الدخول لتفعيل اللعبة والحصول على 5 لآلئ.');
                      }
                      final w = snap.data ?? <String, dynamic>{};
                      final pearls = (w['pearls'] as num?)?.toInt();
                      if (pearls == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('لا توجد محفظة بعد لهذه اللعبة.'),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _reload,
                              child: const Text('تفعيل (يحصل على 5 لآلئ)'),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('اللآلئ: $pearls',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 18)),
                          Row(children: [
                            IconButton(
                              tooltip: 'تحديث',
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                            ),
                          ]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Leaderboard
          Text(
            'لوحة المتصدرين (${widget.gameName})',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _leaderboardFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = snap.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('لا يوجد ترتيب بعد. ابدأ اللعب!'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final name = (r['name'] ?? r['userId'] ?? '-').toString();
                    final pearls = (r['pearls'] ?? 0).toString();
                    return ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('$pearls 💎'),
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
}
