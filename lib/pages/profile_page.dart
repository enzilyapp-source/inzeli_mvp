import 'package:flutter/material.dart';
import '../state.dart';
import '../widgets/game_ring.dart';
import '../api_user.dart';
import '../widgets/pearl_chip.dart';
import '../widgets/fire_badge.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (widget.app.userId == null) return;
    setState(() => _loadingStats = true);
    final s = await getUserStats(widget.app.userId!, token: widget.app.token);
    setState(() {
      _stats = s;
      _loadingStats = false;
    });
  }

  // سلسلة انتصارات متتالية (محليًا باستخدام timeline)
  int _currentWinStreak(AppState app) {
    final me = app.me.name;
    int streak = 0;
    // timeline الأحدث بالأخير عندك؟ نضمن الفرز من الأحدث للأقدم:
    final items = List.of(app.timeline)..sort((a, b) => b.ts.compareTo(a.ts));
    for (final t in items) {
      final iWon = t.winner == me;
      final iPlayed = iWon || t.losers.contains(me);
      if (!iPlayed) continue;
      if (iWon) {
        streak += 1;
      } else {
        break; // انكسرت السلسلة
      }
    }
    return streak;
    // ملاحظة: لو تبغى تعتمد على الـ backend لاحقًا، نستدعي endpoint لسجل اللاعب.
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final me  = app.me;
    final on  = Theme.of(context).colorScheme.onSurface;

    final headlineName = (app.displayName?.trim().isNotEmpty ?? false)
        ? app.displayName!
        : me.name;

    final subLine = (app.email?.trim().isNotEmpty ?? false)
        ? app.email!
        : (me.phone ?? '');

    final wins = (_stats?['wins'] as num?)?.toInt() ?? 0;
    final losses = (_stats?['losses'] as num?)?.toInt() ?? 0;
    final permScore = app.permanentScore ?? 0;
    final credits   = app.creditPoints ?? 0;
    final streak    = _currentWinStreak(app);

    // نسبة تعبئة الحلقة من 0..1 بناءً على permScore (شكل توضيحي)
    final fill01 = ((permScore % 100) / 100.0).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة البروفايل الرئيسية
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: on.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // الصورة + حلقة صغيرة أعلى الصورة (إحساس pro)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 108, height: 108,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        builder: (_, v, __) {
                          return Transform.scale(
                            scale: v,
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: on.withOpacity(0.08),
                              child: const Icon(Icons.person, size: 56),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 4, left: 4, right: 4,
                      child: SizedBox(
                        height: 108,
                        child: IgnorePointer(
                          ignoring: true,
                          child: CustomPaint(
                            painter: _SmallArcPainter(color: const Color(0xFF4CB6FF)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // الاسم + لؤلؤة بجانبه
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        headlineName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 22, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PearlChip(pearls: permScore),
                  ],
                ),

                if (subLine.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subLine,
                      style: TextStyle(color: on.withOpacity(0.6)),
                    ),
                  ),

                const SizedBox(height: 12),
                // شارة النار لو في سلسلة
                FireBadge(streak: streak),

                const SizedBox(height: 16),

                // كروت أرقام سريعة
                _QuickStatsGrid(
                  loading: _loadingStats,
                  items: [
                    QuickStat(icon: Icons.emoji_events_rounded, label: 'فوز', value: wins.toString()),
                    QuickStat(icon: Icons.close_rounded, label: 'خسارة', value: losses.toString()),
                    QuickStat(icon: Icons.stars_rounded, label: 'النقاط', value: permScore.toString()),
                    QuickStat(icon: Icons.account_balance_wallet_rounded, label: 'الرصيد', value: credits.toString()),
                  ],
                ),

                const SizedBox(height: 14),
                // حلقة تقدّم كبيرة (تقدر تربطها بمستوى اللاعب)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 150,
                        child: GameRing(size: 150, fill01: fill01),
                      ),
                      const SizedBox(height: 8),
                      Text('مستوى التقدّم', style: TextStyle(color: on.withOpacity(0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // إنجازات (واجهة صوريّة الآن)
          Text('الإنجازات', style: TextStyle(
              fontWeight: FontWeight.w900, color: on, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _AchievementIcon(icon: Icons.gps_fixed_rounded, label: 'دقّة'),
              _AchievementIcon(icon: Icons.star_rate_rounded, label: 'تميّز'),
              _AchievementIcon(icon: Icons.flag_rounded, label: 'سبّاق'),
              _AchievementIcon(icon: Icons.local_fire_department_rounded, label: 'سلسلة'),
            ],
          ),

          const SizedBox(height: 18),
          // نبذة
          Text('نبذة', style: TextStyle(
              fontWeight: FontWeight.w900, color: on, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            app.bio50?.isNotEmpty == true ? app.bio50! : 'أضف نبذة قصيرة (حتى 50 حرفًا) من ملفك.',
            style: TextStyle(color: on.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _SmallArcPainter extends CustomPainter {
  final Color color;
  _SmallArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color;
    final r = Rect.fromCircle(center: Offset(size.width/2, size.height/2), radius: size.width/2 - 4);
    // قوس صغير فقط
    canvas.drawArc(r, -0.5, 1.2, false, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AchievementIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AchievementIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: on.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: on.withOpacity(0.7))),
      ],
    );
  }
}

class QuickStat {
  final IconData icon;
  final String label;
  final String value;
  QuickStat({required this.icon, required this.label, required this.value});
}

class _QuickStatsGrid extends StatelessWidget {
  final List<QuickStat> items;
  final bool loading;
  const _QuickStatsGrid({required this.items, required this.loading});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 76,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: on.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on.withOpacity(0.08)),
          ),
          child: loading
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: on.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(it.icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(it.value, style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18, height: 1.0)),
                    const SizedBox(height: 2),
                    Text(it.label, style: TextStyle(color: on.withOpacity(0.7))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
