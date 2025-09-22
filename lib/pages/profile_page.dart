import 'package:flutter/material.dart';
import '../state.dart';
import '../widgets/game_ring.dart';
import '../api_user.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _bio = TextEditingController();
  Map<String, dynamic>? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _bio.text = widget.app.bio50 ?? '';
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (widget.app.userId == null) return;
    setState(() => _loadingStats = true);
    final s = await getUserStats(
      widget.app.userId!,
      token: widget.app.token,
      // gameId: widget.app.selectedGame, // اختياري: احصائية لعبة محددة
    );
    setState(() {
      _stats = s;
      _loadingStats = false;
    });
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final me  = app.me;

    final allGames = <String>{};
    for (final list in app.games.values) { allGames.addAll(list); }

    final headlineName = (app.displayName?.trim().isNotEmpty ?? false)
        ? app.displayName!
        : me.name;
    final subLine = (app.email?.trim().isNotEmpty ?? false)
        ? app.email!
        : (me.phone ?? '');

    final credit = app.creditPoints ?? 0;
    final perm   = app.permanentScore ?? 0;

    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // بطاقة الحساب
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headlineName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                if (subLine.isNotEmpty)
                  Text(subLine, style: TextStyle(color: onSurface.withOpacity(0.65))),
                const SizedBox(height: 10),

                // الرصيد/النقاط + فوز/خسارة
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatChip(icon: Icons.account_balance_wallet_rounded, label: 'الرصيد', value: '$credit'),
                    _StatChip(icon: Icons.stars_rounded, label: 'النقاط', value: '$perm'),
                    if (_loadingStats)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (_stats != null) ...[
                      _StatChip(icon: Icons.emoji_events_outlined, label: 'فوز', value: '${_stats!['wins'] ?? 0}'),
                      _StatChip(icon: Icons.close_rounded, label: 'خسارة', value: '${_stats!['losses'] ?? 0}'),
                    ],
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _bio,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'بايو (50 حرف)'),
                  onChanged: (v) => app.setBio(v),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        const Text('تقدّمك في الألعاب', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: allGames.map((g) {
            final info = app.levelForGame(me.name, g);
            final pts  = me.pointsByGame[g] ?? 0;
            return Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameRing(size: 70, fill01: info.fill01),
                  const SizedBox(height: 8),
                  Text(g, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(info.name, style: TextStyle(color: onSurface.withOpacity(0.7))),
                  const SizedBox(height: 6),
                  Text('النقاط: $pts', style: TextStyle(color: onSurface.withOpacity(0.6))),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurface.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: onSurface.withOpacity(0.7))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
