// lib/pages/sponsor_page.dart
import 'package:flutter/material.dart';
import '../api_sponsor.dart';
import '../state.dart';

class SponsorPage extends StatefulWidget {
  final AppState app;
  const SponsorPage({super.key, required this.app});

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  Future<List<Map<String, dynamic>>>? _sponsorsFuture;
  String? _openSponsorCode;
  Future<Map<String, dynamic>>? _sponsorDetailFuture;
  Future<List<Map<String, dynamic>>>? _walletsFuture;

  @override
  void initState() {
    super.initState();
    _sponsorsFuture = ApiSponsors.listSponsors();
  }

  void _openSponsor(String code) {
    setState(() {
      _openSponsorCode = code;
      _sponsorDetailFuture = ApiSponsors.getSponsor(code);
      _walletsFuture = (widget.app.token != null)
          ? ApiSponsors.myWallets(code, widget.app.token!)
          : Future.value(<Map<String, dynamic>>[]);
    });
  }

  void _joinSponsor() async {
    if (_openSponsorCode == null || widget.app.token == null) return;
    try {
      await ApiSponsors.joinSponsor(_openSponsorCode!, widget.app.token!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تفعيل السبونسر ✅')));
      setState(() {
        _walletsFuture =
            ApiSponsors.myWallets(_openSponsorCode!, widget.app.token!);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('قائمة السبونسر',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: onSurface, fontSize: 18)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                // Left column — list of sponsors
                Expanded(
                  flex: 2,
                  child: Card(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _sponsorsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final list = snap.data ?? [];
                        if (list.isEmpty) {
                          return const Center(
                              child: Text('لا يوجد سبونسر حالياً'));
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (_, i) {
                            final s = list[i];
                            final code = s['code']?.toString() ?? '';
                            final name = s['name']?.toString() ?? code;
                            final selected = code == _openSponsorCode;
                            return ListTile(
                              selected: selected,
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              subtitle: Text(code),
                              onTap: () => _openSponsor(code),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Right column — sponsor details
                Expanded(
                  flex: 3,
                  child: _openSponsorCode == null
                      ? const Center(child: Text('اختر سبونسر من القائمة'))
                      : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FutureBuilder<
                                    Map<String, dynamic>>(
                                  future: _sponsorDetailFuture,
                                  builder: (context, snap) {
                                    if (snap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Text('يتم التحميل...');
                                    }
                                    if (snap.hasError ||
                                        snap.data == null) {
                                      return const Text(
                                          'تعذر تحميل بيانات السبونسر');
                                    }
                                    final s = snap.data!;
                                    final name = s['name'] ??
                                        _openSponsorCode ??
                                        'سبونسر';
                                    return Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18));
                                  },
                                ),
                              ),
                              if (app.isSignedIn)
                                FilledButton.icon(
                                  onPressed: _joinSponsor,
                                  icon: const Icon(Icons.how_to_reg),
                                  label: const Text('تفعيل السبونسر'),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          Text('الألعاب المدعومة',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: onSurface)),
                          const SizedBox(height: 6),

                          // List of games
                          Expanded(
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: _sponsorDetailFuture,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snap.hasError || snap.data == null) {
                                  return const Center(
                                      child:
                                      Text('تعذر تحميل بيانات الألعاب'));
                                }
                                final games = (snap.data!['games'] as List?)
                                    ?.cast<Map<String, dynamic>>() ??
                                    [];
                                if (games.isEmpty) {
                                  return const Center(
                                      child: Text('لا توجد ألعاب حالياً'));
                                }
                                return ListView.separated(
                                  itemCount: games.length,
                                  separatorBuilder: (_, __) =>
                                  const Divider(height: 0),
                                  itemBuilder: (_, i) {
                                    final g = games[i];
                                    final gameName =
                                        g['gameName']?.toString() ??
                                            g['gameId']?.toString() ??
                                            '-';
                                    final prize =
                                    (g['prizeAmount'] ?? 0).toString();
                                    return ListTile(
                                      title: Text(gameName,
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w900)),
                                      subtitle: Text('جائزة: $prize'),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),
                          Text('رصيدي في هذا السبونسر',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: onSurface)),
                          const SizedBox(height: 6),

                          // Wallets horizontal list
                          SizedBox(
                            height: 140,
                            child: FutureBuilder<
                                List<Map<String, dynamic>>>(
                              future: _walletsFuture,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final w = snap.data ?? [];
                                if (w.isEmpty) {
                                  return const Center(
                                      child: Text(
                                          'لا توجد لآلئ بعد — فعّل السبونسر أولاً'));
                                }
                                return ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: w.length,
                                  separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final it = w[i];
                                    final gameId =
                                        it['gameId']?.toString() ?? '-';
                                    final pearls =
                                    (it['pearls'] ?? 0).toString();
                                    return Container(
                                      width: 160,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: onSurface
                                                .withOpacity(0.15)),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text('لعبة $gameId',
                                              style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.w900)),
                                          const Spacer(),
                                          Text('لآلئ: $pearls',
                                              style: TextStyle(
                                                  color: onSurface
                                                      .withOpacity(0.7))),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
