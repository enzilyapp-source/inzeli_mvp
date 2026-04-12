import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../state.dart';

class TimelinePage extends StatefulWidget {
  final AppState app;
  const TimelinePage({super.key, required this.app});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  bool _loading = false;
  String? _lastError;

  String _nameFor(String id) {
    if (id.isEmpty) return '';
    for (final p in widget.app.userProfiles.values) {
      final pid = p['id']?.toString();
      final pub = p['publicId']?.toString();
      if (pid == id || pub == id) {
        final dn = p['displayName']?.toString();
        if (dn != null && dn.isNotEmpty) return dn;
      }
    }
    return id;
  }

  List<String> _friendlyNames(List<String> ids) {
    final raw = ids.map((id) {
      final n = _nameFor(id);
      final looksLikeId = RegExp(r'^[A-Za-z0-9_-]{7,}$').hasMatch(id) ||
          (id.contains('-') && !id.contains(' '));
      if (n == id && looksLikeId && id.length > 6) {
        final short =
            id.length > 6 ? id.substring(id.length - 6).toLowerCase() : id;
        return widget.app.tr(ar: 'لاعب #$short', en: 'Player #$short');
      }
      return n;
    }).toList();

    // Prevent duplicate names (common in team events where data can include
    // both ids and resolved names for the same player).
    final out = <String>[];
    final seen = <String>{};
    for (final name in raw) {
      final key = name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (seen.add(key)) out.add(name.trim());
    }
    return out;
  }

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
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.app
          .syncTimelineFromServer()
          .timeout(const Duration(seconds: 15));
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.app.tr(
                ar: 'تعذر تحديث شسالفه: $e',
                en: 'Could not refresh timeline: $e')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTs(DateTime ts) {
    return '${ts.year}/${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final on = Theme.of(context).colorScheme.onSurface;
    final list = [...app.timeline]
      ..sort((a, b) => b.ts.compareTo(a.ts)); // latest first

    List<String> asStrings(dynamic v) {
      if (v is List) {
        return v
            .map((x) => x.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (v == null) return const [];
      final s = v.toString().trim();
      if (s.isEmpty) return const [];
      return [s];
    }

    List<String> uniqueStrings(Iterable<String> values) {
      final out = <String>[];
      final seen = <String>{};
      for (final raw in values) {
        final s = raw.trim();
        if (s.isEmpty) continue;
        if (seen.add(s)) out.add(s);
      }
      return out;
    }

    List<String> winnersOf(TimelineEntry e) {
      final meta = e.meta ?? const <String, dynamic>{};
      final fromMeta = uniqueStrings([
        ...asStrings(meta['winners']),
        ...asStrings(meta['winnerIds']),
        ...asStrings(meta['winnerUserIds']),
        ...asStrings(meta['winnerName']),
        ...asStrings(meta['winner']),
      ]);
      if (e.winners.isNotEmpty) return uniqueStrings(e.winners);
      if (fromMeta.isNotEmpty) return fromMeta;
      if (e.winner.isNotEmpty) return [e.winner];
      return const [];
    }

    List<String> losersOf(TimelineEntry e) {
      final meta = e.meta ?? const <String, dynamic>{};
      final fromMeta = uniqueStrings([
        ...asStrings(meta['losersDisplay']),
        ...asStrings(meta['losersNames']),
        ...asStrings(meta['losers']),
        ...asStrings(meta['losersIds']),
        ...asStrings(meta['loserNames']),
        ...asStrings(meta['loserIds']),
      ]);
      if (e.losers.isEmpty && fromMeta.isEmpty) return const [];
      return uniqueStrings([...e.losers, ...fromMeta]);
    }

    bool isMatchEvent(TimelineEntry e) {
      final k = e.kind.toLowerCase();
      return k == 'match' || k.contains('match');
    }

    final dir = app.isEnglish ? TextDirection.ltr : TextDirection.rtl;
    // تلخيص سريع لآخر نتائج المباريات
    final recent = list
        .where((e) => isMatchEvent(e) && winnersOf(e).isNotEmpty)
        .take(6)
        .toList();

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(
          app.tr(ar: 'الخط الزمني', en: 'Timeline'),
          style:
              TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: on),
        ),
      ),
      if (_lastError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          child: Text(
            app.tr(ar: 'آخر خطأ: $_lastError', en: 'Last error: $_lastError'),
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
    ];

    if (recent.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            app.tr(ar: 'أحدث النتائج', en: 'Latest results'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      );

      for (final r in recent) {
        final winnerIds = winnersOf(r);
        final winnerNames = _friendlyNames(winnerIds);

        final rawLosers = losersOf(r);
        final losersList = _friendlyNames(rawLosers);
        final isTeamBattle = winnerNames.length > 1 && losersList.length > 1;

        final firstWinnerId = winnerIds.isNotEmpty ? winnerIds.first : '';
        final winnerPearls = app.pointsOf(firstWinnerId, r.game);
        final loserPearls = rawLosers
            .map((l) =>
                '${_friendlyNames([l]).first}: ${app.pointsOf(l, r.game)}')
            .join(app.isEnglish ? ' • ' : ' • ');
        final hasPearls = winnerPearls != 0 ||
            rawLosers.any((l) => app.pointsOf(l, r.game) != 0);

        children.add(_ResultSummaryCard(
          winners: winnerNames,
          losers: losersList,
          teamBattle: isTeamBattle,
          game: r.game,
          ts: _formatTs(r.ts),
          pearlsWinner: winnerPearls,
          pearlsLosers: loserPearls,
          showPearls: hasPearls,
          app: app,
        ));
        children.add(const SizedBox(height: 10));
      }

      children.add(const SizedBox(height: 8));
    }

    // الكروت التفصيلية لكل حدث
    for (var i = 0; i < list.length; i++) {
      final t = list[i];
      if (t.kind != 'level_up' && !isMatchEvent(t)) {
        continue; // نخفي أحداث الروم/النظام في صفحة النتائج
      }
      if (t.kind == 'level_up') {
        final from = t.meta?['from']?.toString() ?? '';
        final to = t.meta?['to']?.toString() ?? '';
        final winnerLabel = _friendlyNames([t.winner]).isNotEmpty
            ? _friendlyNames([t.winner]).first
            : t.winner;
        children.add(_LevelUpCard(
          winner: winnerLabel,
          from: from,
          to: to,
          game: t.game,
          app: app,
          ts: _formatTs(t.ts),
        ));
        children.add(const SizedBox(height: 10));
        continue;
      }

      // نقاط الفائز/الخاسر
      final winnerIds = winnersOf(t);
      final losersRaw = losersOf(t);
      if (winnerIds.isEmpty) continue;
      final winnerNames = _friendlyNames(winnerIds);
      if (winnerNames.isEmpty) continue;
      final losersNames = _friendlyNames(losersRaw);
      final isTeamBattle = winnerNames.length > 1 && losersNames.length > 1;
      final firstWinnerId = winnerIds.isNotEmpty ? winnerIds.first : '';
      final winnerPts = app.pointsOf(firstWinnerId, t.game);
      final loserPts = losersRaw
          .map(
              (l) => '${_friendlyNames([l]).first}: ${app.pointsOf(l, t.game)}')
          .join(' / ');

      // إذا ما في فائز و لا لعبة معروفة نتخطى الكارد
      if (t.game.isEmpty || t.game == '—') {
        continue;
      }

      final winnersDisplay = winnerNames.join(app.isEnglish ? ', ' : '، ');
      final winner = winnersDisplay.isEmpty
          ? app.tr(ar: 'غير معروف', en: 'Unknown')
          : winnersDisplay;
      final losersList = losersNames;
      final losers = losersList.isNotEmpty
          ? losersList.join(app.isEnglish ? ', ' : '، ')
          : app.tr(ar: 'لا يوجد', en: 'None');

      // streak متتالي لنفس الفائز/الفريق (من هذا الحدث للخلف)
      int streak = 0;
      for (var j = i; j < list.length; j++) {
        final e = list[j];
        if (!isMatchEvent(e)) continue;
        final ewinners = _friendlyNames(winnersOf(e));
        if (ewinners.isEmpty) continue;
        final sameWinner = ewinners.any((w) => winnerNames.contains(w));
        if (!sameWinner) break;
        streak += 1;
      }
      final hasPearlsInfo =
          winnerPts != 0 || losersRaw.any((l) => app.pointsOf(l, t.game) != 0);

      final subtitleParts = <String>[
        if (isTeamBattle)
          app.tr(ar: 'فاز الفريق على الفريق', en: 'Team defeated team'),
        if (isTeamBattle)
          app.tr(ar: 'الفريق الفائز: $winner', en: 'Winning team: $winner'),
        if (isTeamBattle)
          app.tr(ar: 'الفريق الخاسر: $losers', en: 'Losing team: $losers'),
        if (!isTeamBattle) app.tr(ar: 'فاز على: $losers', en: 'Beat: $losers'),
        app.tr(
            ar: 'اللعبة: ${t.game.isEmpty ? "—" : t.game}',
            en: 'Game: ${t.game.isEmpty ? "—" : t.game}'),
        if (hasPearlsInfo)
          app.tr(
            ar: 'اللآلئ: $winner $winnerPts${losersRaw.isNotEmpty ? " • الخاسرون: $loserPts" : ""}',
            en: 'Pearls: $winner $winnerPts${losersRaw.isNotEmpty ? " • Losers: $loserPts" : ""}',
          ),
      ];

      children.add(_TimelineCard(
        color: Colors.white.withValues(alpha: 0.06),
        icon: Icons.sports_esports_outlined,
        title: app.tr(
          ar: isTeamBattle ? 'فاز الفريق على الفريق' : 'الفائز: $winner',
          en: isTeamBattle ? 'Team defeated team' : 'Winner: $winner',
        ),
        subtitle: subtitleParts.where((s) => s.isNotEmpty).join('  •  '),
        ts: _formatTs(t.ts),
        direction: TextDirection.rtl,
        streak: streak,
      ));
      children.add(const SizedBox(height: 10));
    }

    return Directionality(
      textDirection: dir,
      child: RefreshIndicator(
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
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: children,
                    ),
        ),
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  final List<String> winners;
  final List<String> losers;
  final bool teamBattle;
  final String game;
  final String ts;
  final int pearlsWinner;
  final String pearlsLosers;
  final bool showPearls;
  final AppState app;

  const _ResultSummaryCard({
    required this.winners,
    required this.losers,
    required this.teamBattle,
    required this.game,
    required this.ts,
    required this.pearlsWinner,
    required this.pearlsLosers,
    required this.showPearls,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    final dir = app.isEnglish ? TextDirection.ltr : TextDirection.rtl;
    final winnerText = winners.isNotEmpty
        ? winners.join(app.isEnglish ? ', ' : '، ')
        : app.tr(ar: 'غير معروف', en: 'Unknown');
    final loserText = losers.isNotEmpty
        ? losers.join(app.isEnglish ? ', ' : '، ')
        : app.tr(ar: 'لا يوجد', en: 'None');
    final shownWinner = winnerText.isEmpty
        ? app.tr(ar: 'غير معروف', en: 'Unknown')
        : winnerText;
    return Directionality(
      textDirection: dir,
      child: Card(
        color: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: const Icon(Icons.flag, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      app.tr(
                        ar: teamBattle
                            ? 'فاز الفريق على الفريق'
                            : 'الفائز $shownWinner على $loserText',
                        en: teamBattle
                            ? 'Team defeated team'
                            : '$shownWinner beat $loserText',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(ts,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              if (teamBattle) ...[
                Text(
                  app.tr(
                      ar: 'الفريق الفائز: $shownWinner',
                      en: 'Winning team: $shownWinner'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  app.tr(
                      ar: 'الفريق الخاسر: $loserText',
                      en: 'Losing team: $loserText'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                app.tr(ar: 'اللعبة: $game', en: 'Game: $game'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              if (showPearls)
                Text(
                  app.tr(
                    ar: 'اللآلئ الآن • الفائز: $pearlsWinner${pearlsLosers.isNotEmpty ? " • الخاسرون: $pearlsLosers" : ""}',
                    en: 'Pearls • winner: $pearlsWinner${pearlsLosers.isNotEmpty ? " • losers: $pearlsLosers" : ""}',
                  ),
                  style: const TextStyle(color: Colors.white70, height: 1.2),
                ),
            ],
          ),
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
  final TextDirection? direction;
  final int streak;
  const _TimelineCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ts,
    this.direction,
    this.streak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final dir = direction ?? Directionality.of(context);
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
                if (streak >= 2) ...[
                  _FireStreakBadge(streak: streak),
                  const SizedBox(width: 8),
                ],
                Text(
                  ts,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Directionality(
              textDirection: dir,
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FireStreakBadge extends StatefulWidget {
  final int streak;
  const _FireStreakBadge({required this.streak});

  @override
  State<_FireStreakBadge> createState() => _FireStreakBadgeState();
}

class _FireStreakBadgeState extends State<_FireStreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final wave = 0.5 + 0.5 * math.sin(t * math.pi * 2);
        final flicker = 0.5 + 0.5 * math.sin((t * math.pi * 7) + 0.7);
        final flameScale = 0.93 + (wave * 0.20);
        final flameLift = -1.8 * math.sin(t * math.pi * 2);
        final flameSway = 0.9 * math.sin(t * math.pi * 2.3);
        final flameTilt = 0.08 * math.sin((t * math.pi * 2) + 0.3);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBF5), Color(0xFFFFF2E4), Color(0xFFFFEAD7)],
            ),
            border: Border.all(
              color: const Color(0xFFFFC79A).withValues(alpha: 0.60),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC185).withValues(alpha: 0.14),
                blurRadius: 5,
                spreadRadius: 0.1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'x${widget.streak}',
                style: const TextStyle(
                  color: Color(0xFF7A3C00),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 5),
              Transform.translate(
                offset: Offset(flameSway, flameLift),
                child: Transform.scale(
                  scale: flameScale,
                  child: Transform.rotate(
                    angle: flameTilt,
                    child: Text(
                      '🔥',
                      style: TextStyle(
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFF7A3A)
                                .withValues(alpha: 0.30 + (flicker * 0.40)),
                            blurRadius: 5 + (flicker * 4),
                          ),
                          Shadow(
                            color: const Color(0xFFFFC065)
                                .withValues(alpha: 0.18 + (flicker * 0.20)),
                            blurRadius: 8 + (flicker * 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelUpCard extends StatelessWidget {
  final String winner;
  final String from;
  final String to;
  final String game;
  final String ts;
  final AppState app;
  const _LevelUpCard({
    required this.winner,
    required this.from,
    required this.to,
    required this.game,
    required this.ts,
    required this.app,
  });

  _NotchStyle _styleOf(String label) {
    switch (label.trim().toLowerCase()) {
      case 'عليمي':
      case 'beginner':
        return const _NotchStyle(
          gradient:
              LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFCE9E2B)]),
          glow: Color(0xFFFFD54F),
        );
      case 'يمشي حاله':
      case 'advance':
        return const _NotchStyle(
          gradient:
              LinearGradient(colors: [Color(0xFFD7A15F), Color(0xFF8A4B2E)]),
          glow: Color(0xFFD7A15F),
        );
      case 'زين':
      case 'زين بعد':
      case 'professional':
      case 'pro':
        return const _NotchStyle(
          gradient:
              LinearGradient(colors: [Color(0xFFEFF3F8), Color(0xFF9FA9B5)]),
          glow: Color(0xFFE0E0E0),
          text: Color(0xFF1B1F24),
        );
      case 'فنان':
      case 'legend':
        return const _NotchStyle(
          gradient:
              LinearGradient(colors: [Color(0xFFA0F3FF), Color(0xFF5CD7F7)]),
          glow: Color(0xFF80DEEA),
          text: Color(0xFF072630),
        );
      case 'فلتة':
      case 'goat':
        return const _NotchStyle(
          gradient:
              LinearGradient(colors: [Color(0xFFB388FF), Color(0xFF512DA8)]),
          glow: Color(0xFFB39DDB),
        );
      default:
        return const _NotchStyle(
          gradient:
              LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF455A64)]),
          glow: Color(0xFF90A4AE),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final toLabel =
        to.isNotEmpty ? to : app.tr(ar: 'مستوى جديد', en: 'New rank');
    final fromLabel = from.isNotEmpty
        ? from
        : app.tr(ar: 'المستوى السابق', en: 'Previous rank');
    final style = _styleOf(toLabel);
    return Card(
      color: const Color(0xFFFFA53A).withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.workspace_premium, color: Color(0xFFFFD54F)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.tr(
                      ar: '$winner وصل مستوى جديد',
                      en: '$winner reached a new rank',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  _NotchPulsePill(label: toLabel, style: style),
                  const SizedBox(height: 6),
                  Text(
                    app.tr(
                        ar: 'من $fromLabel إلى $toLabel • اللعبة: $game',
                        en: 'From $fromLabel to $toLabel • Game: $game'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ts,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotchStyle {
  final Gradient gradient;
  final Color glow;
  final Color text;
  const _NotchStyle({
    required this.gradient,
    required this.glow,
    this.text = Colors.white,
  });
}

class _NotchPulsePill extends StatefulWidget {
  final String label;
  final _NotchStyle style;
  const _NotchPulsePill({required this.label, required this.style});

  @override
  State<_NotchPulsePill> createState() => _NotchPulsePillState();
}

class _NotchPulsePillState extends State<_NotchPulsePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: widget.style.gradient,
            boxShadow: [
              BoxShadow(
                color: widget.style.glow.withValues(alpha: 0.30 + (t * 0.25)),
                blurRadius: 10 + (t * 8),
                spreadRadius: 0.6,
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.style.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}
//timeline_page.dart
