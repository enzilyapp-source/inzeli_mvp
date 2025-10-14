// lib/pages/profile_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../state.dart';
import '../widgets/pearl_chip.dart';   // uses: PearlChip(count: ..., selected: ...)
import '../widgets/streak_flame.dart'; // uses: StreakFlame(streak: ...)

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // thresholds and labels for “الأنواط”
  static const List<int> _milestones = [5, 10, 15, 20, 30];
  static const List<String> _labels = [
    'عليمي', 'يمشي حاله', 'زين', 'فنان', 'فلتة'
  ];

  // local edit buffer for bio
  String _bioDraft = '';

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final game = app.selectedGame ?? '—';
    final meName = app.displayName ?? app.name ?? 'لاعب';
    final pearls = app.permanentScore ?? 0;

    // level ring uses wins/losses for the currently selected game
    final lvl = app.levelForGame(meName, game);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // avatar with partial ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CustomPaint(
                        painter: _RingPainter(fill01: lvl.fill01),
                      ),
                    ),
                    CircleAvatar(
                      radius: 34,
                      child: Text(
                        meName.isNotEmpty ? meName.characters.first : '؟',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(app.email ?? app.phone ?? '—',
                          style: TextStyle(color: onSurface.withOpacity(.7))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatPill(
                            icon: Icons.emoji_events_outlined,
                            label: 'Wins',
                            value: '${app.winsOf(meName, game)}',
                          ),
                          _StatPill(
                            icon: Icons.cancel_outlined,
                            label: 'Losses',
                            value: '${app.lossesOf(meName, game)}',
                          ),
                          _StatPill(
                            icon: Icons.hexagon_outlined,
                            label: 'Pearls',
                            value: '$pearls',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Milestones (الأنواط) row using PearlChip
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأنواط',
                    style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _milestones.map((m) {
                    final got = app.winsOf(meName, game);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PearlChip(count: m, selected: got >= m),
                        const SizedBox(height: 4),
                        Text(
                          _labelFor(m),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(.65),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Current game “level” ring + streak
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(painter: _RingPainter(fill01: lvl.fill01)),
                      Text(
                        lvl.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('اللعبة الحالية: $game',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StreakFlame(streak: _winStreak(meName, game)),
                          const SizedBox(width: 8),
                          Text('سلسلة الانتصارات',
                              style: TextStyle(
                                  color:
                                  onSurface.withOpacity(.75))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Bio
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(app.bio50?.isNotEmpty == true ? app.bio50! : '—'),
            subtitle: const Text('نبذة قصيرة'),
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('تعديل'),
              onPressed: () => _editBio(context),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Sponsor code quick set (optional)
        Card(
          child: ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: Text(
              app.activeSponsorCode == null
                  ? 'لا يوجد كود راعي'
                  : 'الكود: ${app.activeSponsorCode}',
            ),
            subtitle: const Text('Sponsor'),
            trailing: OutlinedButton(
              onPressed: () => _editSponsor(context),
              child: const Text('اختيار/إزالة'),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- helpers ----------

  String _labelFor(int milestone) {
    final idx = _milestones.indexOf(milestone);
    return (idx >= 0 && idx < _labels.length) ? _labels[idx] : '';
    // 5: عليمي, 10: يمشي حاله, 15: زين, 20: فنان, 30: فلتة
  }

  int _winStreak(String user, String game) {
    // simple local streak using timeline (latest-first)
    final list = widget.app
        .userMatches(user)
        .where((t) => t.game == game)
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));

    int streak = 0;
    for (final t in list) {
      if (t.winner == user) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> _editBio(BuildContext context) async {
    final app = widget.app;
    _bioDraft = app.bio50 ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل النبذة'),
        content: TextField(
          autofocus: true,
          maxLength: 50,
          controller: TextEditingController(text: _bioDraft),
          onChanged: (v) => _bioDraft = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              app.setBio(_bioDraft);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _editSponsor(BuildContext context) async {
    final app = widget.app;
    String draft = app.activeSponsorCode ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كود الراعي (اختياري)'),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: draft),
          onChanged: (v) => draft = v,
          decoration: const InputDecoration(hintText: 'مثال: SP-TEST'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              app.setSponsorCode(null);
              Navigator.pop(ctx);
            },
            child: const Text('إزالة'),
          ),
          FilledButton(
            onPressed: () {
              app.setSponsorCode(draft.trim().isEmpty ? null : draft.trim());
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    setState(() {});
  }
}

/* ---------------- painters / small widgets ---------------- */

class _RingPainter extends CustomPainter {
  final double fill01; // 0..1
  _RingPainter({required this.fill01});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 3;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF90CAF9).withOpacity(.25);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = const Color(0xFF29B6F6);

    canvas.drawCircle(c, r, bg);
    final sweep = (fill01.clamp(0, 1) as double) * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fill01 != fill01;
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSurface.withOpacity(.7))),
        ],
      ),
    );
  }
}
