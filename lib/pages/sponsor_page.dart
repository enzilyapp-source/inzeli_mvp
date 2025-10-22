// lib/pages/sponsor_page.dart
import 'package:flutter/material.dart';

import '../state.dart';
import '../api_sponsor.dart';              // uses: listSponsors / getSponsor / myWallets / joinSponsor
import 'sponsor_game_page.dart';

class SponsorPage extends StatefulWidget {
  final AppState app;
  const SponsorPage({super.key, required this.app});

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  // list of active sponsors
  late Future<List<Map<String, dynamic>>> _sponsorsFuture;

  // currently opened sponsor
  String? _openSponsorCode;
  Future<Map<String, dynamic>>? _sponsorDetailFuture;
  Future<List<Map<String, dynamic>>>? _walletsFuture;

  @override
  void initState() {
    super.initState();
    _sponsorsFuture = ApiSponsors.listSponsors();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _openSponsor(String code) {
    setState(() {
      _openSponsorCode = code;
      _sponsorDetailFuture = ApiSponsors.getSponsorDetail(code: code, token: widget.app.token);
      _walletsFuture = (widget.app.token != null)
          ? ApiSponsors.getMyWallets(sponsorCode: code, token: widget.app.token!)
          : Future.value(<Map<String, dynamic>>[]);
    });
  }

  Future<void> _joinSponsor() async {
    if (_openSponsorCode == null) return;
    if (!widget.app.isSignedIn) {
      _msg('سجّل دخول أولًا');
      return;
    }
    try {
      await ApiSponsors.joinSponsor(sponsorCode: _openSponsorCode!, token: widget.app.token!);
      _msg('تم تفعيل السبونسر ✅');
      setState(() {
        _walletsFuture = ApiSponsors.getMyWallets(sponsorCode: _openSponsorCode!, token: widget.app.token!);
      });
    } catch (e) {
      _msg(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'السبونسرات',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: onSurface,
              fontSize: 18,
            ),
          ),
        ),

        // Sponsors list (phone-first)
        Card(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _sponsorsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data ?? const <Map<String, dynamic>>[];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا يوجد سبونسر حاليًا'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final s = list[i];
                  final code = (s['code'] ?? '').toString();
                  final name = (s['name'] ?? code).toString();
                  final selected = code == _openSponsorCode;

                  return ListTile(
                    selected: selected,
                    leading: const Icon(Icons.card_giftcard),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(code),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_left),
                    onTap: () => _openSponsor(code),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Selected sponsor details (games + wallets)
        if (_openSponsorCode != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: _sponsorDetailFuture,
                          builder: (context, snap) {
                            final name = () {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return '...';
                              }
                              if (snap.hasError || snap.data == null) {
                                return _openSponsorCode ?? '—';
                              }
                              // data from /sponsors/:code returns { sponsor, games }
                              final s = snap.data!['sponsor'] as Map<String, dynamic>?;
                              return (s?['name'] ?? _openSponsorCode ?? '—').toString();
                            }();
                            return Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            );
                          },
                        ),
                      ),
                      if (widget.app.isSignedIn)
                        FilledButton.icon(
                          onPressed: _joinSponsor,
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('تفعيل'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'الألعاب المدعومة',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Games list for this sponsor
                  FutureBuilder<Map<String, dynamic>>(
                    future: _sponsorDetailFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError || snap.data == null) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('تعذّر تحميل بيانات الألعاب'),
                        );
                      }
                      final games = (snap.data!['games'] as List?)
                          ?.cast<Map<String, dynamic>>() ??
                          const <Map<String, dynamic>>[];

                      if (games.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('لا توجد ألعاب حاليًا'),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: games.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final g = games[i];
                          final gameId = (g['gameId'] ??
                              (g['game'] as Map?)?['id'] ??
                              '')
                              .toString();
                          final gameName =
                          ((g['game'] as Map?)?['name'] ?? gameId)
                              .toString();
                          final prize =
                          (g['prizeAmount'] ?? 0).toString();

                          return ListTile(
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(
                              gameName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text('جائزة: $prize'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () {
                              // 👉 Open the per-game sponsor screen
                              final code = _openSponsorCode ?? '';
                              if (code.isEmpty) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SponsorGameScreen(
                                    app: widget.app,
                                    sponsorCode: code,       // ✅ non-null String
                                    initialGameId: gameId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'رصيدي عند هذا السبونسر',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Wallets (pearls per game) for this sponsor
                  SizedBox(
                    height: 140,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _walletsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final w = snap.data ?? const <Map<String, dynamic>>[];
                        if (w.isEmpty) {
                          return const Center(
                            child: Text('لا توجد لآلئ بعد — فعِّل السبونسر أولًا'),
                          );
                        }
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: w.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final it = w[i];
                            final gameId =
                            (it['gameId'] ?? (it['game'] as Map?)?['id'] ?? '-').toString();
                            final pearls =
                            (it['pearls'] ?? 0).toString();
                            return Container(
                              width: 168,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: onSurface.withOpacity(0.15),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'لعبة $gameId',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'لآلئ: $pearls',
                                    style: TextStyle(
                                      color:
                                      onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
