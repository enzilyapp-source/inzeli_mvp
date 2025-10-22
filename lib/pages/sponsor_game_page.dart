// lib/pages/sponsor_game_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../state.dart';
import '../api_sponsor.dart';
import '../api_room.dart';
import 'match_page.dart';

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
  Map<String, dynamic>? _sponsor; // sponsor object
  List<Map<String, dynamic>> _games = []; // [{gameId, prizeAmount, game:{id,name,...}}]
  Map<String, int> _pearlsByGame = {}; // gameId -> pearls
  String? _selectedGameId;
  final _joinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGameId = widget.initialGameId;
    _load();
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1) sponsor + games (with prize)
      final detail = await ApiSponsors.getSponsorDetail(
        code: widget.sponsorCode,
        token: widget.app.token ?? '', // <-- ensure non-null String
      );
      _sponsor = detail['sponsor'] as Map<String, dynamic>?;
      final gs = (detail['games'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _games = gs;

      // 2) my wallets for that sponsor (pearls per game)
      final wallets = await ApiSponsors.getMyWallets(
        sponsorCode: widget.sponsorCode,
        token: widget.app.token ?? '', // <-- ensure non-null String
      );
      _pearlsByGame.clear();
      for (final w in (wallets as List)) {
        final gameId = (w['gameId'] ?? w['game']?['id'] ?? '').toString();
        final pearls = (w['pearls'] as num?)?.toInt() ?? 0;
        if (gameId.isNotEmpty) _pearlsByGame[gameId] = pearls;
      }

      // If no selection, pick first
      _selectedGameId ??= _games.isNotEmpty ? _games.first['gameId']?.toString() : null;
    } catch (e) {
      _msg('فشل تحميل بيانات الراعي: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _findGame(String id) {
    try {
      return _games.firstWhere((g) => g['gameId']?.toString() == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createAndOpenRoom(String gameId) async {
    if (!widget.app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    try {
      final room = await ApiRoom.createRoom(
        gameId: gameId,
        hostUserId: widget.app.userId ?? '', // safe default
        token: widget.app.token ?? '',       // <-- ensure non-null String
      );
      _msg('تم إنشاء روم للمباراة ✅');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: widget.app,
            room: room,
            sponsorCode: widget.sponsorCode, // تحويل اللآلئ داخل الراعي
          ),
        ),
      );
      // بعد الرجوع من صفحة المباراة، نحدّث المحافظ
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
    if (code.trim().isEmpty) {
      _msg('أدخل كود روم صحيح');
      return;
    }
    try {
      await ApiRoom.joinByCode(
        code: code.trim(),
        userId: widget.app.userId ?? '',   // safe default
        token: widget.app.token ?? '',     // <-- ensure non-null String
      );
      final room = await ApiRoom.getRoomByCode(code.trim(), token: widget.app.token ?? '');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchPage(
            app: widget.app,
            room: room,
            sponsorCode: widget.sponsorCode, // مهم
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

    return Scaffold(
      appBar: AppBar(
        title: Text('راعي: $sponsorName'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
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
                  final game = g['game'] as Map<String, dynamic>?;
                  final gameId = (g['gameId'] ?? game?['id'] ?? '').toString();
                  final name = (game?['name'] ?? gameId).toString();
                  final cat = (game?['category'] ?? '').toString();
                  final prize = (g['prizeAmount'] as num?)?.toInt() ?? 0;
                  final pearls = _pearlsByGame[gameId] ?? 0;
                  final selected = _selectedGameId == gameId;

                  return _GameCard(
                    title: name,
                    subtitle: cat.isEmpty ? 'لعبة' : cat,
                    prize: prize,
                    pearls: pearls,
                    selected: selected,
                    onTap: () {
                      setState(() => _selectedGameId = gameId);
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Actions for selected game
            if (_selectedGameId == null)
              const Text('اختر لعبة لعرض الخيارات.')
            else
              _ActionPanel(
                sponsorCode: widget.sponsorCode,
                game: _findGame(_selectedGameId!)!,
                pearls: _pearlsByGame[_selectedGameId!] ?? 0,
                onCreateRoom: () => _createAndOpenRoom(_selectedGameId!),
                onJoinRoom: () => _joinAndOpenRoom(_joinCtrl.text, _selectedGameId!),
                joinCtrl: _joinCtrl,
              ),

            const SizedBox(height: 20),

            // Info
            const _InfoCard(
              text:
              'طريقة اللعب داخل صفحة الراعي:\n'
                  '• أنشئ روم للعبة المختارة أو انضمّ لروم موجود.\n'
                  '• عند حسم النتيجة في صفحة المباراة، يتم خصم لؤلؤة من كل خاسر وتوزيعها بالتساوي على الفائزين.\n'
                  '• بما أنّك داخل راعٍ محدّد، التحويل يتم داخل محافظ هذا الراعي لكل لعبة (SponsorGameWallet).\n'
                  '• اجمع اللآلئ واربح الجائزة الخاصة باللعبة!',
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------- Widgets -------------------------------- */

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
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.primary : c.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: c.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.diamond_outlined, size: 18),
                  label: Text('$pearls لؤلؤة'),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.card_giftcard, size: 18),
                  label: Text(prize > 0 ? 'جائزة: $prize' : 'بدون جائزة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final String sponsorCode;
  final Map<String, dynamic> game; // sponsorGame row with embedded game
  final int pearls;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final TextEditingController joinCtrl;

  const _ActionPanel({
    required this.sponsorCode,
    required this.game,
    required this.pearls,
    required this.onCreateRoom,
    required this.onJoinRoom,
    required this.joinCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final gameObj = (game['game'] as Map<String, dynamic>?) ?? const {};
    final gameId = (game['gameId'] ?? gameObj['id'] ?? '').toString();
    final name = (gameObj['name'] ?? gameId).toString();
    final prize = (game['prizeAmount'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اللعبة المختارة: $name',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.diamond_outlined, size: 18),
                  label: Text('$pearls لؤلؤة لديكم'),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text(prize > 0 ? 'الجائزة: $prize' : 'بدون جائزة'),
                ),
                const Spacer(),
                Chip(
                  label: Text('Sponsor: $sponsorCode'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.videogame_asset_outlined),
                    onPressed: onCreateRoom,
                    label: const Text('أنشئ روم لعب الآن'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  child: const Text('انضم'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;
  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Text(text),
    );
  }
}
