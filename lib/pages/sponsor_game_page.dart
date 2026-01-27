// lib/pages/sponsor_game_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../state.dart';
import '../api_sponsor.dart';
import '../api_room.dart';
import 'match_page.dart';
import 'package:geolocator/geolocator.dart';

class SponsorGameScreen extends StatefulWidget {
  final AppState app;
  final String sponsorCode;
  final String? initialGameId;

  const SponsorGameScreen({
    super.key,
    required this.app,
    required this.sponsorCode,
    this.initialGameId,
  });

  @override
  State<SponsorGameScreen> createState() => _SponsorGameScreenState();
}

class _SponsorGameScreenState extends State<SponsorGameScreen> {
  bool _loading = true;
  Map<String, dynamic>? _sponsor;
  List<Map<String, dynamic>> _games = [];
  final Map<String, int> _pearlsByGame = {};
  String? _selectedGameId;

  final TextEditingController joinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGameId = widget.initialGameId;
    _load();
  }

  @override
  void dispose() {
    joinCtrl.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await ApiSponsors.getSponsorDetail(
        code: widget.sponsorCode,
        token: widget.app.token,
      );

      _sponsor = detail['sponsor'] as Map<String, dynamic>?;
      _games =
          (detail['games'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      _pearlsByGame.clear();
      if (widget.app.isSignedIn && (widget.app.token?.isNotEmpty ?? false)) {
        final wallets = await ApiSponsors.getMyWallets(
          sponsorCode: widget.sponsorCode,
          token: widget.app.token!,
        );
        for (final w in wallets) {
          final gameId = (w['gameId'] ?? w['game']?['id'] ?? '').toString();
          final pearls = (w['pearls'] as num?)?.toInt() ?? 0;
          if (gameId.isNotEmpty) _pearlsByGame[gameId] = pearls;
        }
      }

      _selectedGameId ??=
      _games.isNotEmpty ? _games.first['gameId']?.toString() : null;
    } catch (e) {
      _msg('فشل تحميل بيانات الراعي: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAndOpenRoom(String gameId) async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    if (widget.app.token == null || widget.app.token!.isEmpty) {
      _msg('التوكن غير موجود. سجّل الدخول من جديد.');
      return;
    }

    try {
      final pos = await _getLocation();
      final room = await ApiRoom.createRoom(
        gameId: gameId,
        sponsorCode: widget.sponsorCode,
        token: widget.app.token,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );

      _msg('تم إنشاء روم للمباراة ✅');
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: widget.app,
            room: room,
            sponsorCode: widget.sponsorCode,
          ),
        ),
      );

      unawaited(_load());
    } catch (e) {
      _msg('تعذّر إنشاء الغرفة: $e');
    }
  }

  Future<void> _joinAndOpenRoom(String code, String gameId) async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    if (widget.app.token == null || widget.app.token!.isEmpty) {
      _msg('التوكن غير موجود. سجّل الدخول من جديد.');
      return;
    }

    try {
      await ApiRoom.joinByCode(
        code: code.trim(),
        token: widget.app.token,
      );

      final room = await ApiRoom.getRoomByCode(
        code.trim(),
        token: widget.app.token,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: widget.app,
            room: room,
            sponsorCode: widget.sponsorCode,
          ),
        ),
      );

      unawaited(_load());
    } catch (e) {
      _msg('تعذّر الانضمام: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sponsorName = _sponsor?['name']?.toString() ?? widget.sponsorCode;

    void onSelectGame(String gameId) {
      setState(() => _selectedGameId = gameId);
    }

    Future<void> onCreateRoom() async {
      final gid = _selectedGameId;
      if (gid == null || gid.isEmpty) {
        _msg('اختَر اللعبة أولًا');
        return;
      }
      await _createAndOpenRoom(gid);
    }

    Future<void> onJoinRoom() async {
      final code = joinCtrl.text.trim();
      if (code.isEmpty) {
        _msg('اكتب كود الروم للانضمام');
        return;
      }
      final gid = _selectedGameId;
      if (gid == null || gid.isEmpty) {
        _msg('اختَر اللعبة أولًا');
        return;
      }
      await _joinAndOpenRoom(code, gid);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('راعي: $sponsorName'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الألعاب المدعومة والجوائز',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_games.isEmpty)
              const Text('لا توجد ألعاب مضافة لهذا الراعي بعد.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _games.map((g) {
                  final gameObj =
                      (g['game'] as Map<String, dynamic>?) ?? const {};
                  final gameId =
                  (g['gameId'] ?? gameObj['id'] ?? '').toString();
                  final name =
                  (gameObj['name'] ?? gameId).toString();
                  final cat =
                  (gameObj['category'] ?? 'لعبة').toString();
                  final prize =
                      (g['prizeAmount'] as num?)?.toInt() ?? 0;
                  final pearls = _pearlsByGame[gameId] ?? 0;
                  final selected = _selectedGameId == gameId;

                  return _GameCard(
                    title: name,
                    subtitle: cat,
                    prize: prize,
                    pearls: pearls,
                    selected: selected,
                    onTap: () => onSelectGame(gameId),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            Text(
              'اختر طريقة اللعب',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCreateRoom,
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('انزلي'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: joinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'كود روم للانضمام',
                      hintText: 'مثال: ABC123',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onJoinRoom,
                  child: const Text('شرّف'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int prize;
  final int pearls;
  final bool selected;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.prize,
    required this.pearls,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.sports_esports_outlined,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard, size: 16),
                        const SizedBox(width: 4),
                        Text('جائزة: $prize د.ك'),
                        const SizedBox(width: 12),
                        const Icon(Icons.circle, size: 10),
                        const SizedBox(width: 4),
                        Text('لآلئك: $pearls'),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
