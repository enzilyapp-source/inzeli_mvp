// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import '../state.dart';
import '../widgets/game_ring.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _bio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bio.text = widget.app.bio50 ?? '';
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final me = app.me;

    // ألعابك نفسها
    final allGames = <String>{};
    for (final list in app.games.values) {
      allGames.addAll(list);
    }

    // لو مسجّل دخول نعرض بيانات الباكند،
    // غير كذا نرجع للملف المحلي القديم (me)
    final headlineName = app.displayName?.trim().isNotEmpty == true
        ? app.displayName!
        : me.name;

    final subLine = app.email?.trim().isNotEmpty == true
        ? app.email!
        : (me.phone ?? '');

    final credit = app.creditPoints ?? 0;       // الرصيد المؤقت
    final perm   = app.permanentScore ?? 0;     // النقاط الدائمة

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ===== بطاقة الحساب (حافظنا على أسلوبك) =====
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headlineName,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                if (subLine.isNotEmpty)
                  Text(subLine, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 10),

                // صف رصيد/نقاط بشكل بسيط ما يغيّر ستايلك
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'الرصيد',
                      value: '$credit',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.stars_rounded,
                      label: 'النقاط',
                      value: '$perm',
                    ),
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

        // ===== شبكـة التقدّم (كما هي عندك) =====
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: allGames.map((g) {
            final info = app.levelForGame(me.name, g);
            final pts = me.pointsByGame[g] ?? 0;
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
                  Text(info.name, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('النقاط: $pts', style: const TextStyle(color: Colors.white60)),
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
    final fg = Theme.of(context).textTheme.bodyMedium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEADFCC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: fg?.copyWith(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
