// lib/pages/profile_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../state.dart';
import '../widgets/pearl_chip.dart';   // uses: PearlChip(count: ..., selected: ...)
import '../widgets/streak_flame.dart'; // uses: StreakFlame(streak: ...)
import 'store_page.dart';
import 'my_items_page.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // thresholds and labels for “الأنواط”
  static const List<int> _milestones = [5, 10, 15, 20, 30];
  List<String> _labels(AppState app) => [
    app.tr(ar: 'عليمي', en: 'Beginner'),
    app.tr(ar: 'يمشي حاله', en: 'Advance'),
    app.tr(ar: 'زين', en: 'Professional'),
    app.tr(ar: 'فنان', en: 'Legend'),
    app.tr(ar: 'فلتة', en: 'GOAT'),
  ];

  // local edit buffer for bio
  String _bioDraft = '';
  bool _pearlsExpanded = false;

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openStore(AppState app) async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StorePage(app: app)),
    );
    setState(() {});
  }

  Future<void> _openItems(AppState app) async {
    if (!app.isSignedIn) {
      _msg('سجّل الدخول أولاً');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyItemsPage(app: app)),
    );
    setState(() {});
  }

  void _openSettings(AppState app) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        String selected = app.isEnglish ? 'en' : 'ar';
        bool muted = app.soundMuted ?? false;
        bool privateProfile = app.profilePrivate ?? false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إعدادات التطبيق', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text('اللغة', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {selected},
                    onSelectionChanged: (s) {
                      selected = s.first;
                      app.setLanguage(selected);
                      setState(() {});
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: muted,
                    onChanged: (v) {
                      muted = v;
                      app.setSoundMuted(v);
                      setState(() {});
                      setSheet(() {});
                    },
                    title: const Text('كتم الصوت'),
                    subtitle: const Text('إيقاف المؤثرات الصوتية'),
                  ),
                  SwitchListTile(
                    value: privateProfile,
                    onChanged: (v) {
                      privateProfile = v;
                      app.setProfilePrivate(v);
                      setState(() {});
                      setSheet(() {});
                    },
                    title: const Text('إخفاء الملف الشخصي'),
                    subtitle: const Text('عند الإخفاء يظهر في البحث الثيم + أفضل لعبة + فوز/خسارة فقط'),
                  ),
                  const SizedBox(height: 8),
                  const Text('بعد التحويل إلى الإنجليزية تظهر كلمة "انزلي" كـ "Start" في الأزرار.'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final game = app.selectedGame ?? '—';
    final gameLabel = app.gameLabel(game);
    final meName = app.displayName ?? app.name ?? 'لاعب';

    // عدد اللآلئ من creditPoints
    final pearls = app.creditPoints ?? 0;
    final credit = app.storeCredit;

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
                        meName.isNotEmpty
                            ? meName.characters.first
                            : '؟',
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'إعدادات',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => _openSettings(app),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.email ?? app.phone ?? '—',
                        style: TextStyle(
                          color: onSurface.withOpacity(.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatPill(
                            icon: Icons.emoji_events_outlined,
                            label: app.tr(ar: 'فوز', en: 'Wins'),
                            value: '${app.winsOf(meName, game)}',
                          ),
                          _StatPill(
                            icon: Icons.cancel_outlined,
                            label: app.tr(ar: 'خسارة', en: 'Losses'),
                            value: '${app.lossesOf(meName, game)}',
                          ),
                          _StatPill(
                            icon: Icons.hexagon_outlined,
                            label: app.tr(ar: 'لآلئ', en: 'Pearls'),
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

      const SizedBox(height: 8),

      // Quick actions row
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _QuickActionChip(
            icon: Icons.settings_outlined,
            label: app.tr(ar: 'الإعدادات', en: 'Settings'),
            onTap: () => _openSettings(app),
          ),
          _QuickActionChip(
            icon: Icons.shopping_bag_outlined,
            label: app.tr(ar: 'المتجر', en: 'Market'),
            onTap: () => _openStore(app),
          ),
          _QuickActionChip(
            icon: Icons.style_outlined,
            label: app.tr(ar: 'ثيماتي', en: 'My Themes'),
            onTap: () => _openItems(app),
          ),
        ],
      ),

      const SizedBox(height: 12),

      // Pearls per game (collapsible)
      Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _pearlsExpanded = !_pearlsExpanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      app.tr(ar: 'لآلئي لكل لعبة', en: 'Pearls per game'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Icon(_pearlsExpanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
                if (_pearlsExpanded) ...[
                  const SizedBox(height: 10),
                  Column(
                    children: _gamePearlEntries(app).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Image.asset(
                              'lib/assets/pearl.png',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                ),
                                child: Text(
                                  '${entry.$1} — ${entry.$2}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF1A949),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),

      // Store actions
      Card(
        child: ListTile(
          leading: const Icon(Icons.shopping_bag_outlined),
          title: const Text('متجر الثيمات والإطارات'),
          subtitle: Text('رصيد الشراء: $credit'),
          trailing: FilledButton(
            onPressed: () => _openStore(app),
            child: const Text('فتح المتجر'),
          ),
        ),
      ),

      if (app.ownedDewanyahs.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.tr(ar: 'ديوانياتي', en: 'My Dewanyahs'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...app.ownedDewanyahs.map<Widget>((d) {
                  final name = (d['name'] ?? 'ديوانية').toString();
                  final gameId = (d['gameId'] ?? '—').toString();
                  final status = (d['status'] ?? 'pending').toString();
                  final pearls = (d['startingPearls'] ?? 5).toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_3_outlined),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(app.tr(
                        ar: 'اللعبة: $gameId • يبدأ بـ $pearls لؤلؤة',
                        en: 'Game: $gameId • Starts with $pearls pearls',
                      )),
                      trailing: _StatusBadge(label: status),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],

      const SizedBox(height: 12),

      // Milestones (الأنواط) row using PearlChip
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.tr(ar: 'الأنواط', en: 'Ranks'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
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
                      CustomPaint(
                        painter: _RingPainter(fill01: lvl.fill01),
                      ),
                      Text(
                        _rankName(lvl.name),
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
                      Text(
                        app.tr(ar: 'اللعبة الحالية: $gameLabel', en: 'Current game: $gameLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StreakFlame(
                            streak: _winStreak(meName, game),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            app.tr(ar: 'سلسلة الانتصارات', en: 'Win streak'),
                            style: TextStyle(
                              color: onSurface.withOpacity(.75),
                            ),
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

        // Bio
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(
              app.bio50?.isNotEmpty == true ? app.bio50! : '—',
            ),
            subtitle: Text(app.tr(ar: 'نبذة قصيرة', en: 'Bio')),
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: Text(app.tr(ar: 'تعديل', en: 'Edit')),
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
            subtitle: Text(app.tr(ar: 'راعي', en: 'Sponsor')),
            trailing: OutlinedButton(
              onPressed: () => _editSponsor(context),
              child: Text(app.tr(ar: 'اختيار/إزالة', en: 'Select / Remove')),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- helpers ----------

  String _labelFor(int milestone) {
    final labels = _labels(widget.app);
    final idx = _milestones.indexOf(milestone);
    return (idx >= 0 && idx < labels.length) ? labels[idx] : '';
    // 5: عليمي, 10: يمشي حاله, 15: زين, 20: فنان, 30: فلتة
  }

  String _rankName(String name) {
    return widget.app.tr(
      ar: name,
      en: switch (name) {
        'عليمي' => 'Beginner',
        'يمشي حاله' => 'Advance',
        'زين' => 'Professional',
        'فنان' => 'Legend',
        'فلتة' => 'GOAT',
        'بدايات' => 'Newbie',
        _ => name,
      },
    );
  }

  List<(String, int)> _gamePearlEntries(AppState app) {
    final entries = <(String, int)>[];
    for (final cat in app.games.values) {
      for (final g in cat) {
        entries.add((app.gameLabel(g), app.pearlsForGame(g)));
      }
    }
    final seen = <String>{};
    final uniq = <(String, int)>[];
    for (final e in entries) {
      if (seen.add(e.$1)) uniq.add(e);
    }
    uniq.sort((a, b) => a.$1.compareTo(b.$1));
    return uniq;
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
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
          decoration:
          const InputDecoration(hintText: 'مثال: SP-TEST'),
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
              app.setSponsorCode(
                draft.trim().isEmpty ? null : draft.trim(),
              );
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
    final sweep =
        (fill01.clamp(0, 1) as double) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fill01 != fill01;
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final lc = label.toLowerCase();
    Color color;
    String text;
    if (lc.contains('pending') || lc.contains('قيد')) {
      color = Colors.amber;
      text = 'قيد التفعيل';
    } else if (lc.contains('live') || lc.contains('open')) {
      color = Colors.greenAccent;
      text = 'مفتوحة';
    } else {
      color = Colors.blueGrey.shade200;
      text = label;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF1A949);
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: accent),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
      shape: StadiumBorder(side: BorderSide(color: accent.withOpacity(0.35))),
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withOpacity(.7),
            ),
          ),
        ],
      ),
    );
  }
}
//profile_page.dart
