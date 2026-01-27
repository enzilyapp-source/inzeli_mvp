import 'package:flutter/material.dart';
import '../state.dart';

class TimelinePage extends StatefulWidget {
  final AppState app;
  const TimelinePage({super.key, required this.app});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChange);
    _sync();
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChange);
    super.dispose();
  }

  void _onAppChange() {
    if (mounted) setState(() {}); // rebuild when timeline changes
  }

  Future<void> _sync() async {
    setState(() => _loading = true);
    await widget.app.syncTimelineFromServer();
    if (mounted) setState(() => _loading = false);
  }

  String _formatTs(DateTime ts) {
    return '${ts.year}/${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final on = Theme.of(context).colorScheme.onSurface;
    final list = app.timeline.reversed.toList(); // latest first

    return RefreshIndicator(
      onRefresh: _sync,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
                ? Center(
                    child: Text(
                      app.tr(ar: 'لا أحداث بعد', en: 'No events yet'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Text(
                            app.tr(ar: 'الخط الزمني', en: 'Timeline'),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: on),
                          ),
                        );
                      }
                      final t = list[i - 1];
                      if (t.kind == 'level_up') {
                        final from = t.meta?['from']?.toString() ?? '';
                        final to = t.meta?['to']?.toString() ?? '';
                        return _TimelineCard(
                          color: const Color(0xFFFFA53A).withValues(alpha: 0.15),
                          icon: Icons.emoji_events,
                          title: app.tr(
                            ar: '${t.winner} ارتقى من $from إلى $to',
                            en: '${t.winner} leveled up from $from to $to',
                          ),
                          subtitle: app.tr(ar: 'اللعبة: ${t.game}', en: 'Game: ${t.game}'),
                          ts: _formatTs(t.ts),
                        );
                      }

                      // نقاط الفائز/الخاسر
                      final winnerPts = app.pointsOf(t.winner, t.game);
                      final loserPts = t.losers
                          .map((l) => '$l: ${app.pointsOf(l, t.game)}')
                          .join(' / ');

                      return _TimelineCard(
                        color: Colors.white.withValues(alpha: 0.06),
                        icon: Icons.sports_esports_outlined,
                        title: app.tr(
                          ar: 'فائز: ${t.winner}',
                          en: 'Winner: ${t.winner}',
                        ),
                        subtitle: [
                          if (t.losers.isNotEmpty)
                            app.tr(ar: 'خاسر: ${t.losers.join("، ")}', en: 'Loser: ${t.losers.join(", ")}'),
                          app.tr(ar: 'اللعبة: ${t.game}', en: 'Game: ${t.game}'),
                          if (winnerPts != 0 || t.losers.isNotEmpty)
                            app.tr(
                              ar: 'النقاط: ${t.winner} $winnerPts ${t.losers.isNotEmpty ? "• الخاسرون: $loserPts" : ""}',
                              en: 'Points: ${t.winner} $winnerPts${t.losers.isNotEmpty ? " • Losers: $loserPts" : ""}',
                            ),
                        ].where((s) => s.isNotEmpty).join('  •  '),
                        ts: _formatTs(t.ts),
                      );
                    },
                  ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String ts;
  const _TimelineCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  ts,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
//timeline_page.dart
