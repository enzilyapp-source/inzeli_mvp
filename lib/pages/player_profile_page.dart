//player_profile_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state.dart';
import '../widgets/avatar_effects.dart';

class PlayerProfilePage extends StatelessWidget {
  final AppState app;
  final String playerName;
  const PlayerProfilePage({super.key, required this.app, required this.playerName});

  @override
  Widget build(BuildContext context) {
    const headerBg = Color(0xFF1E2F4D);
    const cardBg = Color(0xFF132339);
    String norm(String? s) => (s ?? '').trim().toLowerCase();
    final isMe = norm(playerName) == norm(app.displayName) ||
        norm(playerName) == norm(app.name) ||
        norm(playerName) == norm(app.email) ||
        norm(playerName) == norm(app.userId) ||
        norm(playerName) == norm(app.publicId);
    final isPrivate = (app.profilePrivate ?? false) && !isMe;
    final profileKey = isMe ? (app.displayName ?? playerName) : playerName;
    Map<String, dynamic>? backendProfile;
    if (app.userProfiles.containsKey(profileKey)) {
      backendProfile = app.userProfiles[profileKey];
    }
    final p = app.profile(profileKey) ??
        (backendProfile != null
            ? PlayerProfile(
                phone: backendProfile['phone']?.toString(),
                displayName: backendProfile['displayName']?.toString(),
                avatarUrl: backendProfile['avatarUrl']?.toString(),
                avatarBase64: backendProfile['avatarBase64']?.toString(),
                themeId: backendProfile['themeId']?.toString(),
              )
            : null) ??
        (isMe
            ? PlayerProfile(
                phone: app.phone,
                displayName: app.displayName,
                avatarUrl: app.avatarPath,
                avatarBase64: app.avatarBase64,
                themeId: app.themeId,
              )
            : null);
    final stats = app.userStats[profileKey];
    final game = app.selectedGame ?? '';
    final w = (stats?['wins'] as num?)?.toInt() ?? app.winsOf(profileKey, game);
    final l = (stats?['losses'] as num?)?.toInt() ?? app.lossesOf(profileKey, game);
    final matches = app.userMatches(profileKey);
    final notFound = p == null && stats == null && backendProfile == null && !isMe;
    final displayId = isMe
        ? (app.publicId ?? app.userId ?? '')
        : (stats?['publicId']?.toString() ?? stats?['id']?.toString() ?? '');

    Map<String, int> pearls = {};
    final gp = stats?['gamePearls'];
    if (gp is Map) {
      pearls = gp.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    } else {
      pearls = app.gamePearls;
    }

    final (topGame, topPearls) = _topPearlGame(pearls, app);
    final recentWins = _recentWins(matches, profileKey, app);
    String rankLabelForPearls(int pearls) {
      if (pearls >= 30) return app.tr(ar: 'فلتة', en: 'GOAT');
      if (pearls >= 20) return app.tr(ar: 'فنان', en: 'Legend');
      if (pearls >= 15) return app.tr(ar: 'زين', en: 'Pro');
      if (pearls >= 10) return app.tr(ar: 'يمشي حاله', en: 'Advance');
      if (pearls >= 5) return app.tr(ar: 'عليمي', en: 'Beginner');
      return app.tr(ar: 'بدايات', en: 'New');
    }
    final rankLabel = rankLabelForPearls(topPearls);

    // avatar & theme
    ImageProvider? avatarImage;
    final avatarB64 = p?.avatarBase64 ?? backendProfile?['avatarBase64']?.toString();
    final avatarUrl = p?.avatarUrl ?? backendProfile?['avatarUrl']?.toString();
    final themeId = p?.themeId ?? backendProfile?['themeId']?.toString();
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(avatarB64));
      } catch (_) {}
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl);
    }
    AvatarEffectType? effectFromId(String? id) {
      switch (id) {
        case 'blueThunder':
          return AvatarEffectType.blueThunder;
        case 'goldLightning':
          return AvatarEffectType.goldLightning;
        case 'kuwait':
          return AvatarEffectType.kuwaitSparkles;
        case 'greenLeaf':
          return AvatarEffectType.greenLeaf;
        case 'flameBlue':
          return AvatarEffectType.flameBlue;
        default:
          return null;
      }
    }
    final avatarEffect = effectFromId(themeId) ?? AvatarEffectType.blueThunder;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1D32),
      appBar: AppBar(title: Text('ملف: $playerName')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Hero card
          Card(
            elevation: 6,
            clipBehavior: Clip.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              height: 170,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: -18,
                    child: _PearlBadge(
                      game: topGame,
                      pearls: topPearls,
                      size: 62,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFF1A949)),
                          const SizedBox(width: 6),
                          Text(rankLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: -18,
                    child: _TrophyStrip(
                      recentWins: recentWins,
                      size: 44,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarEffect(
                          effect: avatarEffect,
                          size: 112,
                          animate: true,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundImage: avatarImage,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            child: avatarImage == null
                                ? Text(
                                    _initials(playerName),
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          playerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        if (displayId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _shortId(displayId),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatPill(icon: Icons.emoji_events_outlined, label: 'فوز', value: '$w'),
                  _StatPill(icon: Icons.cancel_outlined, label: 'خسارة', value: '$l'),
                  _StatPill(icon: Icons.sports_esports_outlined, label: 'مباريات', value: '${w + l}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (pearls.isNotEmpty)
            Card(
              color: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _PearlCircleGrid(
                  entries: _pearlEntries(pearls, app),
                  maxValue: 30,
                ),
              ),
            ),

          if (!isPrivate && !notFound && matches.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('آخر المباريات', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70)),
            const SizedBox(height: 6),
            ...matches.map((t)=> Card(
              color: cardBg,
              child: ListTile(
                leading: const Icon(Icons.sports_esports_outlined, color: Colors.white70),
                title: Text('${t.game} — ${t.roomCode}', style: const TextStyle(color: Colors.white)),
                subtitle: Directionality(
                  textDirection: app.isEnglish ? TextDirection.ltr : TextDirection.rtl,
                  child: Text(
                    'فائز: ${t.winner} • خاسرون: ${t.losers.join(app.isEnglish ? ', ' : '، ')}\n${t.ts}',
                    maxLines: 2,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s)=>s.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.characters.take(2).toString();
  return (parts[0].characters.take(1).toString() +
      parts[1].characters.take(1).toString());
}

(String, int) _topPearlGame(Map<String, int> pearls, AppState app) {
  if (pearls.isNotEmpty) {
    final top = pearls.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (app.gameLabel(top.key), top.value);
  }
  final fallback = app.selectedGame ?? '—';
  return (app.gameLabel(fallback), app.pearlsForGame(fallback));
}

List<(String, DateTime)> _recentWins(List<TimelineEntry> matches, String player, AppState app) {
  final wins = matches.where((t) => t.winner == player).toList()
    ..sort((a, b) => b.ts.compareTo(a.ts));
  return wins.take(3).map((t) => (app.gameLabel(t.game), t.ts)).toList();
}

List<(String, int)> _pearlEntries(Map<String, int> pearls, AppState app) {
  final list = pearls.entries.map((e) => (app.gameLabel(e.key), e.value)).toList();
  list.sort((a, b) => a.$1.compareTo(b.$1));
  return list;
}

String _shortId(String id) {
  final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (clean.isEmpty) return '';
  final short = clean.length > 6 ? clean.substring(clean.length - 6) : clean.padLeft(6, '0');
  return '#$short';
}

class _PearlBadge extends StatelessWidget {
  final String game;
  final int pearls;
  final double size;
  const _PearlBadge({required this.game, required this.pearls, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final double topOffset = size * 0.2;
    final double bottomOffset = size * 0.18;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: Text(
              '$pearls',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1E2F4D),
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
              ),
            ),
          ),
          Positioned(
            bottom: bottomOffset,
            left: 8,
            right: 8,
            child: Text(
              game,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrophyStrip extends StatelessWidget {
  final List<(String, DateTime)> recentWins;
  final double size;
  const _TrophyStrip({required this.recentWins, this.size = 46});

  @override
  Widget build(BuildContext context) {
    const trophyFill = Color(0xFFE3E6EF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        if (i >= recentWins.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TrophyCircle(
              label: '—',
              date: null,
              filled: false,
              color: Colors.white.withValues(alpha: .4),
              size: size,
            ),
          );
        }
        final t = recentWins[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _TrophyCircle(
            label: t.$1,
            date: t.$2,
            filled: true,
            color: trophyFill,
            size: size,
          ),
        );
      }),
    );
  }
}

class _TrophyCircle extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool filled;
  final Color color;
  final double size;
  const _TrophyCircle({required this.label, required this.date, required this.filled, required this.color, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? Colors.black : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: size * 0.35, color: Colors.amber),
            if (filled) ...[
              SizedBox(height: size * 0.05),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.22,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PearlCircleGrid extends StatelessWidget {
  final List<(String, int)> entries;
  final int maxValue;
  const _PearlCircleGrid({required this.entries, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('لا توجد بيانات', style: TextStyle(color: Colors.white70));
    const accent = Color(0xFFF1A949);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries.map((e) {
        final game = e.$1;
        final value = e.$2.clamp(0, maxValue);
        final pct = value / maxValue;
        return SizedBox(
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 74,
                    height: 74,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        progress: pct,
                        color: accent,
                        bgColor: Colors.grey.shade700,
                        strokeWidth: 7,
                      ),
                    ),
                  ),
                  Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Text(game, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  _ArcPainter({required this.progress, required this.color, required this.bgColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.bgColor != bgColor || oldDelegate.strokeWidth != strokeWidth;
  }
}
//pages/player_profile_pages
